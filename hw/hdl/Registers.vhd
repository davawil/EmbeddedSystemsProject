library ieee;
use ieee.std_logic_1164.all;

entity Registers is
    port (
        command_data:       out std_logic_vector(15 downto 0) := (others => '0');
        Received_data:      out std_logic := '0';
        writing_command:    out std_logic := '0';
        listening_command:  in std_logic;
        send_IRQ:           in std_logic;

        get_buffer_addr:    in std_logic;
        buffer_info:        out std_logic_vector(31 downto 0) := (others => '0');
        buffer_addr_valid:  out std_logic := '0';
        synchronized:       out std_logic := '0';
        start:              out std_logic := '0';
        frame_addr_rdy:     out std_logic := '0';
        

        -- avalon slave connections
        Clk:        in std_logic;
        nReset:     in std_logic;
        AS_add:     in std_logic_vector(3 downto 0);
        AS_CS:      in std_logic;
        AS_wr:      in std_logic;
        AS_WData:   in std_logic_vector(31 downto 0);
        AS_BE:      in std_logic_vector(3 downto 0);
        AS_Rd:      in std_logic;
        AS_RData:   out std_logic_vector(31 downto 0) := (others => '0');
        AS_IRQ:     out std_logic := '0';
        AS_WaitRq:  out std_logic := '0'
    );
end Registers;


architecture comp of Registers is

type regState is  (WRITING_REGISTERS, WRITE_LCD);
type irqState is  (WAITING_RQST, WAITING_RESP, WAIT_IRQ_CLEAR);

signal stateRegControl:             regState := WRITING_REGISTERS;
signal stateIrq:                    irqState := WAITING_RQST;

-- registers declaration
signal frontImageAddr:		        std_logic_vector(31 downto 0) := x"00000000";
signal backImageAddr:		        std_logic_vector(31 downto 0) := x"00000000";
signal startReg:		            std_logic;
signal commandData:		            std_logic_vector(15 downto 0);
signal cameraRdy:  		            std_logic := '1';
signal wrt_command:                 std_logic := '0';
signal pendingIRQ:                  std_logic := '0';

-- signals declaration
signal isFrontBuffer:               std_logic := '1';
signal needToSendIRQ:               std_logic := '0';
signal sync_local:                   std_logic := '0';

begin
    
    process(clk, nReset)
        begin
            if nReset = '0' then
            elsif rising_edge(clk) then
                synchronized <= sync_local;
                if AS_wr = '1' then
                    case(AS_add) is
                        when "0000" => 
                            frontImageAddr <= AS_WData;
                        when "0001" => 
                            backImageAddr <= AS_WData;
                        when "0010" => 
                            startReg <= AS_WData(0);
                            start <= AS_WData(0);
                            buffer_addr_valid <= AS_WData(0);
                            synchronized <= AS_WData(0);
                            sync_local <= AS_WData(0);
                        when "0011" => commandData <= AS_WData(15 downto 0);
                        when "0100" => 
                            wrt_command <= AS_WData(0);
                            writing_command <= AS_WData(0);
                        when "0101" => cameraRdy <= AS_WData(0);
                        when "0110" => pendingIRQ <= AS_WData(0);
                        when others => null;
                    end case;
                end if;

                -- TODO simplify
                case(stateRegControl) is
                    when WRITING_REGISTERS => 
                        
                        if AS_wr = '1' then
                            if wrt_command = '1' and AS_add = "0011" then
                                AS_WaitRq <= '1';
                                Received_data <= '1';
                                stateRegControl <= WRITE_LCD;
                            end if;
                        end if;
                    when WRITE_LCD =>
                        command_data <= commandData;
                        if listening_command = '1' and wrt_command = '1' then
                            AS_WaitRq <= '0';
                            Received_data <= '0';
                            stateRegControl <= WRITING_REGISTERS;
                        elsif wrt_command = '0' then
                            AS_WaitRq <= '0';
                            Received_data <= '0';
                            stateRegControl <= WRITING_REGISTERS;
                        end if;
                    when others => null;
                end case;

                case (stateIrq) is
                    when WAITING_RQST =>
                        if sync_local = '1' then
                            sync_local <= '0';
                        end if;
                        if send_IRQ = '1' then
                            pendingIRQ <= '1';
                            cameraRdy <= '1';
                            AS_IRQ <= '1';
                            stateIrq <= WAIT_IRQ_CLEAR;
                        end if;
                    
                    when WAIT_IRQ_CLEAR =>
                        if pendingIRQ = '0' then
                            AS_IRQ <= '0';
                            stateIrq <= WAITING_RESP;
                        end if;
                    
                    when WAITING_RESP =>
                        if cameraRdy = '0' then
                            cameraRdy <= '1';
                            sync_local <= '1';
                            stateIrq <= WAITING_RQST;
                        end if;
                    when others => null;             
                end case;

                if get_buffer_addr = '1' then
                    frame_addr_rdy <= '1';
                    if isFrontBuffer = '1' then
                        buffer_info <= frontImageAddr;
                    else
                        buffer_info <= backImageAddr;
                    end if;
                    isFrontBuffer <= not isFrontBuffer;
                else 
                    frame_addr_rdy <= '0';
                end if;

                

            end if;
        end process;
        
        process(clk)
        begin 
            if rising_edge(clk) then 
            AS_RData <= (others => '0'); 
            if AS_Rd = '1' then 
                case(AS_add) is
                    when "0000" => AS_RData <= frontImageAddr;
                    when "0001" => AS_RData <= backImageAddr;
                    when "0010" => AS_RData(0) <= startReg;
                    when "0011" => AS_RData(15 downto 0) <= commandData;
                    when "0100" => AS_RData(0) <= wrt_command;
                    when "0101" => AS_RData(0) <= cameraRdy;
                    when "0110" => AS_RData(0) <= pendingIRQ;
                    when others => null;
                end case;
            end if;
        end if;
        end process;

end comp;