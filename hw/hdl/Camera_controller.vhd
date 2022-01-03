library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Camera_controller is
	port(
		clk		: 	in std_logic;
		nReset	:	in std_logic;

		--DMA
		AM_WaitRequest 		: in std_logic;
		AM_irq				: out std_logic;
		AM_Address 			: out std_logic_vector(31 downto 0);
		AM_Write			: out std_logic;
		AM_DataWr			: out std_logic_vector(31 downto 0);

		--AVALON Slave
		AS_Address 			: in std_logic_vector(1 downto 0);
		AS_Wr				: in std_logic;
		AS_DataWr			: in std_logic_vector(31 downto 0);

		--Camera Interface
		C_pixclk			: in std_logic;
		C_data				: in std_logic_vector(11 downto 0);
		C_FVAL				: in std_logic;
		C_LVAL				: in std_logic;

		--Camera signals
		CameraClk			: out std_logic;									--clock to output to camera (divide if using cmos)
		CameraReset_n		: out std_logic
	);
	end Camera_controller;

architecture comp of Camera_controller is

  signal FBuff0		: std_logic_vector(31 downto 0);
  signal FBuff1		: std_logic_vector(31 downto 0);
  signal start		: std_logic;
  --signal start_DMA	: std_logic;
  --signal start_CI		: std_logic;

  --FIFO signals
  signal RdFifo		: std_logic;
  signal WrFifo		: std_logic;
  signal RdData		: std_logic_vector(15 downto 0);
  signal WrData		: std_logic_vector(15 downto 0);
  signal fifo_full	: std_logic;
  signal fifo_empty 	: std_logic;
  signal used_words 	: std_logic_vector(7 downto 0);
  signal Fifo_almost_empty : std_logic;

	component fifo is
    port(
      clock		: IN STD_LOGIC ;
      data		: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
      rdreq		: IN STD_LOGIC ;
      wrreq		: IN STD_LOGIC ;
      empty		: OUT STD_LOGIC ;
      full		: OUT STD_LOGIC ;
      q			: OUT STD_LOGIC_VECTOR (15 DOWNTO 0);
      usedw		: OUT STD_LOGIC_VECTOR (7 DOWNTO 0)
    );
	end component fifo;

	component DMA_sub is
		port(
			clk         	: in std_logic;
			nReset      	: in std_logic;
			WaitRequest 	: in std_logic;
			irq				: out std_logic;
			Address 		: out std_logic_vector(31 downto 0);
			Wr				: out std_logic;
			DataWr			: out std_logic_vector(31 downto 0);
			RdFifo			: out std_logic;
			Fifo_almost_empty		: in std_logic;
			RdData			: in std_logic_vector(15 downto 0);
			FBuff0			: in std_logic_vector(31 downto 0);
			FBuff1			: in std_logic_vector(31 downto 0);
			start_DMA		: in std_logic
		);
	end component DMA_sub;

	component AS_sub is
		port(
			clk         	: in std_logic;
			nReset      	: in std_logic;
			Address 		: in std_logic_vector(1 downto 0);
			Wr				: in std_logic;
			DataWr			: in std_logic_vector(31 downto 0);
			FBuff0			: out std_logic_vector(31 downto 0);
			FBuff1			: out std_logic_vector(31 downto 0);
			start			: out std_logic
		);
	end component AS_sub;

	component Camera_interface_sub is
		port(
			clk         	: in std_logic;
			nReset      	: in std_logic;
			pixclk			: in std_logic;
			data			: in std_logic_vector(11 downto 0);
			FVAL			: in std_logic;
			LVAL			: in std_logic;
			start_CI		: in std_logic;
			WrFIFO			: out std_logic;
			WrData			: out std_logic_vector(15 downto 0)
		);
	end component Camera_interface_sub;

begin
	fifo_inst : fifo PORT MAP (
		clock	 	=> clk,
		data	 	=> WrData,
		rdreq	 	=> RdFifo,
		wrreq	 	=> WrFifo,
		empty	 	=> fifo_empty,
		full	 	=> fifo_full,
		q	 		  => RdData,
		usedw	 	=> used_words
	);

	dma : component DMA_sub
		port map(
			clk      			=> clk,
			nReset      		=> nReset,
			WaitRequest 		=> AM_WaitRequest,
			irq					=> AM_irq,
			Address 			=> AM_Address,
			Wr					=> AM_Write,
			DataWr				=> AM_DataWr,
			RdFifo				=> RdFifo,
			Fifo_almost_empty	=> Fifo_almost_empty,
			RdData				=> RdData,
			FBuff0				=> FBuff0,
			FBuff1				=> FBuff1,
			start_DMA			=> start
		);
	slave : component AS_sub
		port map(
			clk      			=> clk,
			nReset      		=> nReset,
			Address 			=> AS_Address,
			Wr					=> AS_Wr,
			DataWr				=> AS_DataWr,
			FBuff0				=> FBuff0,
			FBuff1				=> FBuff1,
			start				=> start
		);
	camera : component Camera_interface_sub
		port map(
			clk      			=> clk,
			nReset      		=> nReset,
			pixclk				=> C_pixclk,
			data				=> C_data,
			FVAL				=> C_FVAL,
			LVAL				=> C_LVAL,
			start_CI			=> start,
			WrFIFO				=> WrFIFO,
			WrData				=> WrData
		);

  CameraReset_n <= nReset;
  --CameraClk <= clk;
  process(clk, nReset)
    variable clkDiv_count	: natural range 0 to 8 := 0;	--count up to 500 000
  begin
    if nReset = '0' then
      clkDiv_count 	:= 0;
      CameraClk <= '0';
    elsif rising_edge(clk) then
      clkDiv_count 	:= clkDiv_count + 1;

      if clkDiv_count = 8 then
        CameraClk <= '1';
        clkDiv_count	:= 0;
      else
        CameraClk <= '0';
      end if;
      --PLACE HOLDER UNTIL ADDED Fifo_almost_empty
      if used_words < "00000010" then
        Fifo_almost_empty <= '1';
      else
        Fifo_almost_empty <= '0';
      end if;
    end if;
  end process;
end comp;
