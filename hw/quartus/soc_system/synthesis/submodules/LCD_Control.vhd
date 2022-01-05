library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity LCD_Control is
    port (
        nReset:             in std_logic;
        clk:                in std_logic;

        q:		            in std_logic_vector(15 downto 0);
        rdempty:		    in std_logic;
        rdusedw:		    in std_logic_vector(8 downto 0);
        rdreq:		        out std_logic := '0';
        stop:               out std_logic := '0';

        command_data:       in std_logic_vector(15 downto 0);
        Received_data:      in std_logic;
        writing_command:    in std_logic;
        start:              in std_logic;
        listening_command:  out std_logic := '0';
        send_IRQ:           out std_logic := '0';

        LCD_ON:             out std_logic := '1';
        REST_N:             out std_logic := '1';
        CS_N:               out std_logic := '1';
        RS:                 out std_logic := '1';
        WR_N:               out std_logic := '1';
        RD_N:               out std_logic := '1';
        D:                  out std_logic_vector(15 downto 0) := (others => '0')
    );
end LCD_Control;


architecture comp of LCD_Control is

type state is  (SETUP, IDLE, LISTENING_CMD, WRITING_CMD, WRITING_PIXEL, FLUSH_FIFO);

signal lcdState:            state := SETUP;

signal wrPhase:             unsigned(2 downto 0) := (others => '0');
signal pixelCounter:        unsigned(16 downto 0) := (others => '0');

-- signal declaration
signal mustEmptyFifo:       std_logic := '0';
signal flushCyle:           std_logic := '0';


-- constant declaration
constant FIFO_ALMOST_EMPTY: integer := 60; -- TODO check this value
constant TOTAL_PIXELS:      integer := 76800; -- 320 * 240

signal setup_counter:       unsigned(22 downto 0) := (others => '0');
constant THRESHOLD:         integer := TOTAL_PIXELS - FIFO_ALMOST_EMPTY - 1;
constant RESET_LOW_TIME:     integer := 550000;
constant CS_HIGH_TIME:       integer := 6550000;

begin
    process(clk, nReset)
    begin
        if nReset = '0' then
            REST_N <= '0';

        elsif rising_edge(clk) then          

            case (lcdState) is
                when SETUP =>
                    if to_integer(setup_counter) = 0 then
                        REST_N <= '1';
                    elsif to_integer(setup_counter) = 50000 then
                        REST_N <= '0';
                    elsif to_integer(setup_counter) = RESET_LOW_TIME then
                        REST_N <= '1';
                    elsif to_integer(setup_counter) = CS_HIGH_TIME then 
                        CS_N <= '0';
                        lcdState <= IDLE;
                    end if;
                    setup_counter <= setup_counter + 1;

                when IDLE =>
                    wrPhase <= (others => '0');
                    send_IRQ <= '0';
                    if writing_command = '1' then
                        RS <= '0';
                        stop <= '1';
                        lcdState <= LISTENING_CMD;
                    elsif start = '1' then
                        stop <= '0';
                        if to_integer(pixelCounter) < TOTAL_PIXELS and rdempty = '0' then
                        --if to_integer(unsigned(rdusedw)) >= FIFO_ALMOST_EMPTY OR mustEmptyFifo = '1' then
                            --pixelCounter <= pixelCounter + 1;
                            rdreq <= '1';
                            lcdState <= WRITING_PIXEL;
                        end if;
                    end if;

                when WRITING_PIXEL =>
                    rdreq <= '0';
                    case (to_integer(wrPhase)) is
                        when 0 => 
                            RS <= '1';
                            CS_N <= '0';
                            WR_N <= '0';
                            D <= q;
                        when 2 => 
                            WR_N <= '1';
                        when 4 =>
                            --CS_N <= '1';
                            null;
                        when others => null;
                    end case;

                    if to_integer(wrPhase) >= 4 then
                        wrPhase <= (others => '0');
                        if to_integer(pixelCounter) = TOTAL_PIXELS - 1 then
                            pixelCounter <= (others => '0');
                            send_IRQ <= '1';
                        else
                            pixelCounter <= pixelCounter + 1;
                        end if;
                        
                        lcdState <= IDLE;
                    else
                        wrPhase <= wrPhase + 1;
                    end if;

                when LISTENING_CMD =>
                    if writing_command = '0' then
                        --send_IRQ <= '1';
                        lcdState <= FLUSH_FIFO;
                    else
                        if Received_data = '1' then
                            listening_command <= '1';
                            lcdState <= WRITING_CMD;
                        end if;
                    end if;

                when WRITING_CMD =>
                    listening_command <= '0';
                    case (to_integer(wrPhase)) is
                        when 0 => 
                            CS_N <= '0';
                            WR_N <= '0';
                            D <= command_data;
                        when 2 => 
                            WR_N <= '1';
                        when 4 =>
                            --CS_N <= '1';
                            null;
                        when others => null;
                    end case;

                    if to_integer(wrPhase) = 4 then
                        RS <= '1';
                        lcdState <= LISTENING_CMD;
                        wrPhase <= (others => '0');
                    else
                        wrPhase <= wrPhase + 1;
                    end if;
                
                -- empty fifo
                when FLUSH_FIFO =>
                    --lcdState <= IDLE; -- huuuuuu
                    --send_IRQ <= '0';
                    listening_command <= '0';
                    if rdempty = '1' then
                        rdreq <= '0';
                        --send_IRQ <= '1';
                        lcdState <= IDLE;
                    else 
                        rdreq <= '1';
                    end if;

                when others => null;            
            end case;
        end if;


    end process;

end comp;