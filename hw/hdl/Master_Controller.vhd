library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Master_Controller is
    port (
        data:		        out std_logic_vector(31 downto 0)   := (others => '0');
        wrusedw:		    in std_logic_vector(7 downto 0);
        wrreq:		        out std_logic                       := '0';

        stop:               in std_logic;
        get_buffer_addr:    out std_logic                       := '0';
        buffer_info:        in std_logic_vector(31 downto 0);    
        buffer_addr_valid:  in std_logic;
        synchronized:       in std_logic;
        frame_addr_rdy:     in std_logic;

        -- avalon master connections
        AM_Add:     out std_logic_vector(31 downto 0)           := (others => '0');
        AM_BC:      out std_logic_vector(5 downto 0)            := (others => '0');
        AM_BE:      out std_logic_vector(3 downto 0)            := (others => '1');
        AM_Rd:      out std_logic                               := '0';
        AM_RdDtVld: in std_logic;
        AM_RdData:  in std_logic_vector(31 downto 0);
        AM_WaitRq:  in std_logic;

        nReset:     in std_logic;
        clk:        in std_logic
    );
end Master_Controller;


architecture comp of Master_Controller is

type state is  (SETUP, WAIT_BUFFER_ADD, WAIT_SYNC, WAIT_TRANSFER, WAIT_DATA);

signal dma_state:           state := SETUP;

-- signal declaration
signal numberBurstAccess:   unsigned(8 downto 0);
signal numberPixelRead:     unsigned(16 downto 0);
signal frameAddress:        std_logic_vector(31 downto 0);
signal setup_complete:      std_logic := '0';
-- constants declaration
constant BURST_SIZE:        integer := 40;
constant FIFO_ALMOST_FULL:  integer := 160; --one line
constant FRAME_SIZE:        integer := 76800; -- 320 * 240

begin
    process(clk, nReset)
    begin
        if nReset = '0' then

        elsif rising_edge(clk) then
            if stop = '1' then
                AM_Rd <= '0';
                get_buffer_addr <= '0';
                data <= (others => '0');
                dma_state <= SETUP;
            else
                case (dma_state) is
                    when SETUP =>
                        if buffer_addr_valid = '1' then
                            setup_complete <= '1';
                            get_buffer_addr <= '1';
                            dma_state <= WAIT_BUFFER_ADD;
                        end if;
                    when WAIT_BUFFER_ADD =>
                        wrreq <= '0';
                        get_buffer_addr <= '0';
                        if frame_addr_rdy = '1' then
                            frameAddress <= buffer_info;
                            dma_state <= WAIT_SYNC;
                        end if;
                    when WAIT_SYNC =>
                        if synchronized = '1' or setup_complete = '1' then
                            setup_complete <= '0';
                            numberPixelRead <= (others => '0');
                            numberBurstAccess <= (others => '0');
                            dma_state <= WAIT_TRANSFER;
                        end if;
                    when WAIT_TRANSFER =>
                        wrreq <= '0';
                        if to_integer(unsigned(wrusedw)) < FIFO_ALMOST_FULL then
                            AM_Rd <= '1';
                            AM_BC <= std_logic_vector(to_unsigned(BURST_SIZE, AM_BC'length));
                            AM_Add <= frameAddress;
                            if AM_WaitRq = '0' then
                                dma_state <= WAIT_DATA;
                            end if;
                        end if;

                    when WAIT_DATA =>
                        AM_Rd <= '0';
                        AM_BC <= (others => '0');
                        AM_Add <= (others => '0');   

                        if AM_RdDtVld = '1' and to_integer(numberBurstAccess) < BURST_SIZE then
                            numberBurstAccess <= numberBurstAccess + 1;
                            numberPixelRead <= numberPixelRead + 2;

                            if to_integer(numberBurstAccess) = BURST_SIZE - 1 then
                                if to_integer(numberPixelRead) = FRAME_SIZE - 2 then
                                    get_buffer_addr <= '1';
                                    dma_state <= WAIT_BUFFER_ADD;
                                else 
                                    numberBurstAccess <= (others => '0');
                                    frameAddress <= std_logic_vector(to_unsigned(to_integer(unsigned(frameAddress)) + (BURST_SIZE * 4), frameAddress'length)); -- oupsi TODO check addressing mode
                                    dma_state <= WAIT_TRANSFER;
                                end if;
                            end if;

                            -- directly send data to FiFo
                            data <= AM_RdData;
                            wrreq <= '1';
                        else
                            wrreq <= '0';
                        end if;                     
                    when others => null;               
                end case;
            end if;
        end if;
    end process;

end comp;