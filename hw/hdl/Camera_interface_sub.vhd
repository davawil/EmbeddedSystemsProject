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
	type state_count_type is (s0, s1, s2, s3, s4, s5);
  signal state_count : state_count_type;
  signal col : unsigned(11 downto 0) := (others => '0');
  signal row : unsigned(11 downto 0) := (others => '0');
  signal highest_bit : unsigned(3 downto 0) := (others => '0');
  signal pix_max : std_logic_vector(11 downto 0) := (others => '0');
  signal lowest_bit_RB : unsigned(3 downto 0) := (others => '0');
  signal lowest_bit_G : unsigned(3 downto 0) := (others => '0');

begin

  count_proc: process(pixclk, nReset)
  begin
    if nReset = '0' then
      state_count <= s0;
      row <= x"000";
      col <= x"000";
    elsif rising_edge(pixclk) then
      case state_count is
        when s0 =>
          if start_CI = '1' then
            state_count <= s1;
          end if;

        when s1 =>
          if FVAL = '1' and LVAL = '1' then
            col <= col + 1;
            if col >= x"27F" then --0x27F = 639
              state_count <= s2;
            end if;
          end if;

        when s2 =>
          row <= row + 1;
          col <= x"000";
          if row < x"1DF" then
            state_count <= s1;
          else
            state_count <= s3;
          end if;

        when s3 =>
          row <= x"000";
          highest_bit <= x"6";
          state_count <= s4;

        when s4 =>
          for bit_i in 11 downto 0 loop
            if pix_max(bit_i) = '1' or bit_i = 6 then
              highest_bit <= to_unsigned(bit_i, 4);
              exit;
            end if;
          end loop;
          state_count <= s5;

        when s5 =>
          lowest_bit_RB <= highest_bit - 5;
          lowest_bit_G <= highest_bit - 6;
          pix_max <= x"000";
          state_count <= s1;
      end case;
    end if;
  end process count_proc;


end comp;
