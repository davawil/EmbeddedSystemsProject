library ieee; 
use ieee.std_logic_1164.all; 
use ieee.numeric_std.all;

entity DMA_sub is
	port(
			clk         	: in std_logic;
			nReset      	: in std_logic;
			WaitRequest 	: in std_logic;
			irq				: out std_logic;
			Address 		: out std_logic_vector(31 downto 0);
			Wr				: out std_logic;
			DataWr			: out std_logic_vector(31 downto 0);
			RdFifo			: out std_logic;
			Fifo_almost_empty		: in std_logic;								--when there are less than 2 words
			RdData			: in std_logic_vector(15 downto 0);
			FBuff0			: in std_logic_vector(31 downto 0);
			FBuff1			: in std_logic_vector(31 downto 0);
			start_DMA		: in std_logic
		);
	end DMA_sub;

architecture comp of DMA_sub is
	type State is(S_Init, S_Idle, S_Acq, S_Wait, S_Write, S_Inc, S_BuffInc, S_Hold);

	signal SM			: State 				:= S_Idle;	
	signal acq			: std_logic 			:= '0';
	signal pixCount		: unsigned(31 downto 0) := (others => '0');
	signal buffSel		: std_logic 			:= '0';
	signal start 		: std_logic				:= '0';
	signal int_Address	: unsigned(31 downto 0) := (others => '0');
begin
	Address <= std_logic_vector(int_Address);
	process(clk, nReset)
	begin
		if nReset = '0' then
			irq <= '0';
			Wr <= '0';
			RdFifo <= '0';
			DataWr <= (others => '0');
			SM <= S_Init;
			acq <= '0';
			buffSel <= '0';
			int_Address <= unsigned(FBuff0);
		elsif rising_edge(clk) then
			if start_DMA = '1' then
				start <= '1';
			end if;
			case SM is
				when S_Init =>
					if start = '1' then
						SM <= S_Idle;
					end if;
					int_Address <= unsigned(FBuff0);
				when S_Idle =>
					start <= '0';
					irq <= '0';
					if Fifo_almost_empty = '0' then
						SM <= S_Acq;
						RdFifo <= '1';
					end if;
				when S_Acq =>
					if acq = '0' then
						acq <= '1';
						DataWr(15 downto 0) <= RdData;
						SM <= S_Acq;
						RdFifo <= '1';
					else
						SM <= S_Wait;
						RdFifo <= '0';
						acq <= '0';
						DataWr(31 downto 16) <= RdData;
					end if;
				when S_Wait =>
					if WaitRequest = '0' then
						SM <= S_Write;
					end if;
				when S_Write =>
					SM <= S_Inc;
					Wr <= '1';
					
				when S_Inc =>
					if pixCount < to_unsigned(76798, pixCount'length) then
						SM <= S_Idle;
					else
						SM <= S_BuffInc;
					end if;
					Wr <= '0';
					int_Address <= int_Address + 4;
					pixCount <= pixCount + 2;
				
				when S_BuffInc =>
					buffSel <= not buffSel;
					SM <= S_Hold;
					
				when S_Hold =>
					if buffSel = '0' then
						int_Address <= unsigned(FBuff0);
					else
						int_Address <= unsigned(FBuff1);
					end if;
					pixCount <= to_unsigned(0, pixCount'length);		
					irq <= '1';
					if start = '1' then
						SM <= S_Idle;
					end if;
			end case;
		end if;
	end process;

end comp;