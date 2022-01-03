library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Camera_interface_sub is
	port(
			clk         	: in std_logic;
			nReset      	: in std_logic;
			pixclk		  	: in std_logic;
			data			  	: in std_logic_vector(11 downto 0);
			FVAL			  	: in std_logic;
			LVAL			  	: in std_logic;
			start_CI			: in std_logic;
			WrFIFO			  : out std_logic;
			WrData			  : out std_logic_vector(15 downto 0)
		);
	end Camera_interface_sub;

architecture comp of Camera_interface_sub is


  --Signals count_proc
	type state_count_type is (s_init, s_inc_col, s_inc_row, s_rst_row, s_highest_bit, s_rst_max);
  signal state_count : state_count_type;
  signal col : unsigned(11 downto 0) := (others => '0');
  signal row : unsigned(11 downto 0) := (others => '0');
  signal highest_bit : integer range 6 to 11;
  signal pix_max : std_logic_vector(11 downto 0) := (others => '0');
  signal shift_G : integer range 0 to 5;
  signal shift_RB : integer range 0 to 6;


  --Signals merge_colors_proc
  type state_merge_colors is (s_init, s_start, s_g, s_shift, s_merge, s_wr_fifo, s_wait);
  signal state_color : state_merge_colors;
  signal green_1 : std_logic_vector(11 downto 0);
  signal red : std_logic_vector(11 downto 0);
  signal blue : std_logic_vector(11 downto 0);
  signal green_2 : std_logic_vector(11 downto 0);
  signal green : std_logic_vector(11 downto 0);
  signal pixel : std_logic_vector(15 downto 0);
  signal sum : std_logic_vector(11 downto 0);
  signal start : std_logic := '0';
  signal pixclk_sig : std_logic_vector(1 downto 0);

  --Fifo signals
  signal RdFifo_g : std_logic := '0';
  signal RdFifo_r : std_logic := '0';
  signal WrFifo_g : std_logic := '0';
  signal WrFifo_r : std_logic := '0';
  signal empty_g : std_logic;
  signal empty_r : std_logic;
  signal full_g : std_logic;
  signal full_r : std_logic;
  signal RdData_g : std_logic_vector(11 downto 0);
  signal RdData_r : std_logic_vector(11 downto 0);
  signal used_words_g : std_logic_vector(8 downto 0);
  signal used_words_r : std_logic_vector(8 downto 0);

  --Buffer for green and red data
  -- type buffer_color is array(319 downto 0) of std_logic_vector(11 downto 0);
  -- signal buffer_r : buffer_color := (others => x"000");
  -- signal buffer_g : buffer_color := (others => x"000");

  component fifo_color is
    PORT(
      clock		: IN STD_LOGIC ;
      data		: IN STD_LOGIC_VECTOR (11 DOWNTO 0);
      rdreq		: IN STD_LOGIC ;
      wrreq		: IN STD_LOGIC ;
      empty		: OUT STD_LOGIC ;
      full		: OUT STD_LOGIC ;
      q		    : OUT STD_LOGIC_VECTOR (11 DOWNTO 0);
      usedw		: OUT STD_LOGIC_VECTOR (8 DOWNTO 0)
    );
    end component fifo_color;

begin
  fifo_g : fifo_color PORT MAP (
		clock	 	=> clk,
		data	 	=> data,
		rdreq	 	=> RdFifo_g,
		wrreq	 	=> WrFifo_g,
		empty	 	=> empty_g,
		full	 	=> full_g,
		q	 		  => RdData_g,
		usedw	 	=> used_words_g
	);

  fifo_r : fifo_color PORT MAP (
		clock	 	=> clk,
		data	 	=> data,
		rdreq	 	=> RdFifo_r,
		wrreq	 	=> WrFifo_r,
		empty	 	=> empty_r,
		full	 	=> full_r,
		q	 		  => RdData_r,
		usedw	 	=> used_words_r
	);

  -- Counts column and rows and defines the range to merge the colors
  count_proc: process(pixclk, nReset)
  begin
    if nReset = '0' then
      state_count <= s_init;
      row <= x"000";
      col <= x"000";
      shift_G <= 0;
      shift_RB <= 0;
    elsif rising_edge(pixclk) then
      case state_count is
        when s_init =>
          if LVAL = '1' and FVAL = '1' then
            state_count <= s_inc_col;
            col <= col + 1;
          end if;

        when s_inc_col =>
          if col >= x"27F" then --0x27F = 639
              state_count <= s_inc_row;
          elsif FVAL = '1' and LVAL = '1' then
            col <= col + 1;
          end if;

        when s_inc_row =>
          col <= x"000";
          if row < x"1DF" then
            state_count <= s_inc_col;
            row <= row + 1;
          else
            state_count <= s_rst_row;
          end if;

        when s_rst_row =>
          row <= x"000";
          highest_bit <= 6;
          state_count <= s_highest_bit;

        when s_highest_bit =>
          for bit_i in 11 downto 0 loop
            if pix_max(bit_i) = '1' or bit_i = 6 then
              highest_bit <= bit_i;
              exit;
            end if;
          end loop;
          state_count <= s_rst_max;

        when s_rst_max =>
          shift_G <= highest_bit - 6;
          shift_RB <= highest_bit - 5;
          -- Transition only when the frame is valid again to not increase the column counter
          state_count <= s_inc_col;
      end case;
    end if;
  end process count_proc;


  -- Counts column and rows and defines the range to merge the colors
  merge_colors_proc: process(clk, nReset)
    --variable idx_buffer: integer := 0;
  begin
    if nReset = '0' then
      state_color <= s_init;
      start <= '0';
      pixclk_sig <= "00";
    elsif rising_edge(clk) then
      if start_CI = '1' then
        start <= '1';
      end if;
      -- Use last known value with current value to detect rising edges
      pixclk_sig <= pixclk_sig(0) & pixclk;
      case state_color is
        when s_init =>
          if start = '1' and row = x"000" and col = x"000" and LVAL = '1' and FVAL='1' then
            state_color <= s_start;
            pix_max <= x"000";
            start <= '0';
          end if;

        when s_start =>
          if row(0) = '0' and col(0) = '0' then
            WrFifo_g <= '1';
            state_color <= s_wait;
          elsif row(0) = '0' and col(0) = '1' then
            WrFifo_r <= '1';
            state_color <= s_wait;
          elsif row(0) = '1' and col(0) = '0' then
            blue <= data;
            state_color <= s_wait;
          else
            green_2 <= data;
            RdFifo_g <= '1';
            RdFifo_r <= '1';
            red <= RdData_r;
            green_1 <= RdData_g;
            state_color <= s_g;
          end if;

        when s_g =>
          RdFifo_g <= '0';
          RdFifo_r <= '0';
          sum <= (green_1 or red or blue or green_2);
          green <= std_logic_vector(shift_right(unsigned(green_1), 1) + shift_right(unsigned(green_2), 1));
          state_color <= s_shift;

        when s_shift =>
          red <= std_logic_vector(shift_right(unsigned(red), shift_RB));
          green <= std_logic_vector(shift_right(unsigned(green), shift_G));
          blue <= std_logic_vector(shift_right(unsigned(blue), shift_RB));
          state_color <= s_merge;

        when s_merge =>
          pixel(4 downto 0) <= blue(4 downto 0);
          pixel(10 downto 5) <= green(5 downto 0);
          pixel(15 downto 11) <= red(4 downto 0);
          state_color <= s_wr_fifo;

        when s_wr_fifo =>
          WrFIFO <= '1';
          WrData <= pixel;
          if sum > pix_max then
            pix_max <= sum;
          end if;
          state_color <= s_wait;

        when s_wait =>
          WrFIFO <= '0';
          WrFifo_g <= '0';
          WrFifo_r <= '0';
          if LVAL = '0' and FVAL = '0' then
            state_color <= s_init;
          elsif pixclk_sig = "01" and LVAL = '1' and FVAL = '1' then
            state_color <= s_start;
          end if;

      end case;
    end if;
  end process merge_colors_proc;
end comp;
