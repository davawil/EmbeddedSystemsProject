library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Camera_interface_sub is
	port(
      -- col_sim     : out std_logic_vector(10 downto 0);
      -- row_sim     : out std_logic_vector(10 downto 0);
      -- h_b_sim     : out unsigned(4 downto 0);
			clk         	: in std_logic;
			nReset      	: in std_logic;
			pixclk			: in std_logic;
			data				: in std_logic_vector(11 downto 0);
			FVAL				: in std_logic;
			LVAL				: in std_logic;
			start_CI			: in std_logic;
			WrFIFO			: out std_logic;
			WrData			: out std_logic_vector(15 downto 0)

		);
	end Camera_interface_sub;

architecture comp of Camera_interface_sub is
  component fifo_color is
  PORT(
		clock		: IN STD_LOGIC ;
		data		: IN STD_LOGIC_VECTOR (11 DOWNTO 0);
		rdreq		: IN STD_LOGIC ;
		wrreq		: IN STD_LOGIC ;
		empty		: OUT STD_LOGIC ;
		full		: OUT STD_LOGIC ;
		q		: OUT STD_LOGIC_VECTOR (11 DOWNTO 0);
		usedw		: OUT STD_LOGIC_VECTOR (8 DOWNTO 0)
	);
  end component fifo_color;

  --Signals count_proc
	type state_count_type is (s_init, s_inc_col, s_inc_row, s_rst_row, s_highest_bit, s_rst_max);
  signal state_count : state_count_type;
  signal col : unsigned(11 downto 0) := (others => '0');
  signal row : unsigned(11 downto 0) := (others => '0');
  signal highest_bit : unsigned(3 downto 0) := (others => '0');
  signal highest_bit_n : integer range 6 to 11;
  signal pix_max : std_logic_vector(11 downto 0) := (others => '0');
  signal lowest_bit_RB : unsigned(3 downto 0) := (others => '0');
  signal lowest_bit_RB_n : integer range 0 to 6;
  signal lowest_bit_G : unsigned(3 downto 0) := (others => '0');
  signal lowest_bit_G_n : integer range 0 to 5;
  signal shift_G : integer range 0 to 5;
  signal shift_RB : integer range 0 to 6;


  --Signals merge_colors_proc
  type state_merge_colors is (s_init, s_start, s_g1, s_r, s_b, s_g2, s_wait, s_g, s_avg_g, s_merge, s_wr_fifo);
  signal state_color : state_merge_colors;
  signal green_1 : std_logic_vector(11 downto 0);
  signal red : std_logic_vector(11 downto 0);
  signal blue : std_logic_vector(11 downto 0);
  signal green_2 : std_logic_vector(11 downto 0);
  signal green : std_logic_vector(11 downto 0);
  signal pixel : std_logic_vector(15 downto 0);
  signal sum : std_logic_vector(11 downto 0);
  signal start_ack : std_logic := '0';



  --Fifo signals
  signal RdFifo_g : std_logic := '0';
  signal RdFifo_r : std_logic := '0';
  signal WrFifo_g : std_logic := '0';
  signal WrFifo_r : std_logic := '0';
  signal RdData_g : std_logic_vector(11 downto 0);
  signal RdData_r : std_logic_vector(11 downto 0);
  signal used_words : std_logic_vector(8 downto 0);


begin
  fifo_g : fifo_color PORT MAP (
		clock	 	=> clk,
		data	 	=> data,
		rdreq	 	=> RdFifo_g,
		wrreq	 	=> WrFifo_g,
		empty	 	=> open,
		full	 	=> open,
		q	 		  => RdData_g,
		usedw	 	=> used_words
	);

  fifo_r : fifo_color PORT MAP (
		clock	 	=> clk,
		data	 	=> data,
		rdreq	 	=> RdFifo_r,
		wrreq	 	=> WrFifo_r,
		empty	 	=> open,
		full	 	=> open,
		q	 		  => RdData_r,
		usedw	 	=> used_words
	);

  -- Counts column and rows and defines the range to merge the colors
  count_proc: process(pixclk, nReset)
  begin
    if nReset = '0' then
      state_count <= s_init;
      row <= x"000";
      col <= x"000";
    elsif rising_edge(pixclk) then
      case state_count is
        when s_init =>
          if start_CI = '1' then
            state_count <= s_inc_col;
          end if;

        when s_inc_col =>
          if FVAL = '1' and LVAL = '1' then
            col <= col + 1;
            if col >= x"27F" then --0x27F = 639
              state_count <= s_inc_row;
            end if;
          end if;

        when s_inc_row =>
          row <= row + 1;
          col <= x"000";
          if row < x"1DF" then
            state_count <= s_inc_col;
          else
            state_count <= s_rst_row;
          end if;

        when s_rst_row =>
          row <= x"000";
          highest_bit <= x"6";
          state_count <= s_highest_bit;

        when s_highest_bit =>
          for bit_i in 11 downto 0 loop
            if pix_max(bit_i) = '1' or bit_i = 6 then
              highest_bit <= to_unsigned(bit_i, 4);
              highest_bit_n <= bit_i;
              exit;
            end if;
          end loop;
          state_count <= s_rst_max;

        when s_rst_max =>
          lowest_bit_RB <= highest_bit - 5;
          lowest_bit_RB_n <= highest_bit_n - 5;
          lowest_bit_G <= highest_bit - 6;
          lowest_bit_G_n <= highest_bit_n - 6;
          shift_G <= highest_bit_n - 6;
          shift_RB <= highest_bit_n - 5;
          state_count <= s_inc_col;
      end case;
    end if;
  end process count_proc;


  -- Counts column and rows and defines the range to merge the colors
  merge_colors_proc: process(clk, nReset)
  begin
    if nReset = '0' then
      state_color <= s_init;
    elsif rising_edge(clk) then
      case state_color is
        when s_init =>
          if start_CI = '1' and row = x"000" and col = x"000" and LVAL = '1' and FVAL='1' then
            state_color <= s_start;
            pix_max <= x"000";
          end if;

        when s_start =>
          start_ack <= '1';
          if row(0) = '0' and col(0) = '0' then
            state_color <= s_g1;
          elsif row(0) = '0' and col(0) = '1' then
            state_color <= s_r;
          elsif row(0) = '1' and col(0) = '0' then
            state_color <= s_b;
          else
            state_color <= s_g2;
          end if;

        -- Color green 1
        when s_g1 =>
          WrFifo_g <= '1';
          state_color <= s_wait;

        -- Color red
        when s_r =>
          WrFifo_r <= '1';
          state_color <= s_wait;

        -- Color blue
        when s_b =>
          blue <= data;
          state_color <= s_wait;

        -- Color green 2
        when s_g2 =>
          green_2 <= data;
          RdFifo_g <= '1';
          RdFifo_r <= '1';
          red <= RdData_r;
          green_1 <= RdData_g;

          state_color <= s_g;

        when s_wait =>
          WrFIFO <= '1';
          WrFifo_g <= '0';
          WrFifo_r <= '0';
          if row = 479 and col = 639 then
            state_color <= s_init;
            start_ack <= '0';
          elsif pixclk = '1' and LVAL = '1' and FVAL = '1' then
            state_color <= s_start;
          end if;

        when s_g =>
          RdFifo_g <= '0';
          RdFifo_r <= '0';
          --sum <= to_unsigned(green_1, 12) + to_unsigned(green_1, 12) + to_unsigned(green_1, 12) + to_unsigned(green_1, 12)green_2
          sum <= (green_1 or red or blue or green_2);
          --green_1 <= std_logic_vector(shift_right(unsigned(green_1), 1));
          --green_2 <= std_logic_vector(shift_right(unsigned(green_2), 1));
          green <= std_logic_vector(shift_right(unsigned(green_1), 1) + shift_right(unsigned(green_2), 1));
          state_color <= s_avg_g;

        when s_avg_g =>
          --green <= std_logic_vector(unsigned(green_1) + unsigned(green_2));
          red <= std_logic_vector(shift_right(unsigned(red), shift_RB));
          green <= std_logic_vector(shift_right(unsigned(green), shift_G));
          blue <= std_logic_vector(shift_right(unsigned(blue), shift_RB));
          state_color <= s_merge;

        when s_merge =>
          --pixel(4 downto 0) <= blue(to_integer(highest_bit) downto to_integer(lowest_bit_RB));
          --pixel(4 downto 0) <= blue(highest_bit_n downto lowest_bit_RB_n);
          pixel(4 downto 0) <= blue(4 downto 0);
          --pixel(10 downto 5) <= green(to_integer(highest_bit) downto to_integer(lowest_bit_G));
          --pixel(10 downto 5) <= green(highest_bit_n downto lowest_bit_G_n);
          pixel(10 downto 5) <= green(5 downto 0);
          --pixel(11 downto 15) <= red(to_integer(highest_bit) downto to_integer(lowest_bit_RB));
          --pixel(11 downto 15) <= red(highest_bit_n downto lowest_bit_RB_n);
          pixel(11 downto 15) <= red(4 downto 0);
          state_color <= s_wr_fifo;

        when s_wr_fifo =>
          WrFIFO <= '1';
          WrData <= pixel;
          if sum > pix_max then
            pix_max <= sum;
          end if;
          state_color <= s_wait;
      end case;
    end if;
  end process merge_colors_proc;
end comp;
