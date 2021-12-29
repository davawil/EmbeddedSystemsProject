library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_camera_interface is
end tb_camera_interface;

architecture test of tb_camera_interface is

  constant CLK_PERIOD: time := 20ns; --Freq of 50MHz
  constant PIXCLK_PERIOD: time := 160ns;--Freq of 6.25MHz
  signal test_finished: boolean := false;


  -- camera_interface port signals
  signal clk: std_logic;
  signal nReset: std_logic := '1';

  -- Avalon slave signals
  signal start_CI: std_logic := '0';
  signal start_CI_ack: std_logic;

  -- FIFO signals
  signal WrFIFO: std_logic := '0';
  signal WrData: std_logic_vector(15 downto 0);

  -- Camera TRDB5 signals
  signal pixclk: std_logic;
  signal data: std_logic_vector(11 downto 0);
  signal FVAL: std_logic;
  signal LVAL: std_logic;

begin

  -- instantiate the pwm port
  dut: entity work.Camera_interface_sub
  port map(
    clk      			=> clk,
    nReset     		=> nReset,
    pixclk				=> pixclk,
    data				  => data,
    FVAL				  => FVAL,
    LVAL				  => LVAL,
    start_CI			=> start_CI,
    start_CI_ack	=> start_CI_ack,
    WrFIFO				=> WrFIFO,
    WrData				=> WrData
  );

  -- continuous clock signal
  clk_generation: process
  begin
      if not test_finished then
          clk <= '1';
          wait for CLK_PERIOD / 2;
          clk <= '0';
          wait for CLK_PERIOD / 2;
      else
          wait;
      end if;
  end process;

  -- continuous clock signal
  pixclk_generation: process
  begin
      if not test_finished then
          pixclk <= '1';
          wait for PIXCLK_PERIOD / 2;
          pixclk <= '0';
          wait for PIXCLK_PERIOD / 2;
      else
          wait;
      end if;
  end process;



  simulation: process
    variable rise_pwm:time;
    variable diff:time;
  begin

    for frames in 0 to 2 loop
      for row in 0 to 479 loop

        wait for 10*PIXCLK_PERIOD;

        FVAL <= '1';

        wait for PIXCLK_PERIOD;

        LVAL <= '1';
        start_CI <= '1';

        for col in 0 to 639 loop
          data <= std_logic_vector(to_unsigned(col, 12));
          wait for PIXCLK_PERIOD;
        end loop;

        LVAL <= '0';

        wait for PIXCLK_PERIOD;

        FVAL <= '0';

      end loop;
      start_CI <= '0';
      wait for 50*PIXCLK_PERIOD;

    end loop;


    -- test done after 155ms
    test_finished <= true;
  end process;

end architecture test;
