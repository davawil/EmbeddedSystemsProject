library ieee;
use ieee.std_logic_1164.all;

entity LCD_Controller is
    port(
        -- Avalon slave
        Clk:        in std_logic;
        nReset:     in std_logic;
        AS_add:     in std_logic_vector(3 downto 0); -- not sure for the 32 bits addr here
        AS_CS:      in std_logic;
        AS_wr:      in std_logic;
        AS_WData:   in std_logic_vector(31 downto 0);
        AS_BE:      in std_logic_vector(3 downto 0);
        AS_Rd:      in std_logic;
        AS_RData:   out std_logic_vector(31 downto 0);
        AS_IRQ:     out std_logic;
        AS_WaitRq:  out std_logic;

        -- Avalon master
        AM_add:     out std_logic_vector(31 downto 0); -- not sure for the 32 bits addr here
        AM_BC:      out std_logic_vector(5 downto 0);
        AM_BE:      out std_logic_vector(3 downto 0);
        AM_Rd:      out std_logic;
        AM_RdDtVld: in std_logic;
        AM_RdData:  in std_logic_vector(31 downto 0);
        AM_WaitRq:  in std_logic;

        -- Conduit
        LCD_ON:     out std_logic;
        REST_N:     out std_logic;
        CS_N:       out std_logic;
        RS:         out std_logic;
        WR_N:       out std_logic;
        RD_N:       out std_logic;
        D:          out std_logic_vector(15 downto 0)
    );
end LCD_Controller;

architecture comp of LCD_Controller is

    -- internal signals declaration
    signal data:		        std_logic_vector(31 downto 0);
    signal wrusedw:		        std_logic_vector(7 downto 0);
    signal wrreq:		        std_logic;
    
    signal q:		            std_logic_vector(15 downto 0);
    signal rdempty:		        std_logic;
    signal rdusedw:		        std_logic_vector(8 downto 0);
    signal rdreq:		        std_logic;

    signal stop:                std_logic;
    signal get_buffer_addr:     std_logic;
    signal buffer_info:         std_logic_vector(31 downto 0);
    signal buffer_addr_valid:   std_logic;
    signal synchronized:        std_logic;
    signal start:               std_logic;
    signal frame_addr_rdy:      std_logic;

    signal command_data:        std_logic_vector(15 downto 0);
    signal Received_data:       std_logic;
    signal writing_command:     std_logic;
    signal listening_command:   std_logic;
    signal send_IRQ:            std_logic;

    -- components declaration
    component fifo_lcd is -- signals names need to be redifined once we have the intel FiFo
        port (
            data		: in std_logic_vector(31 downto 0);
            rdclk		: in std_logic;
            rdreq		: in std_logic;
            wrclk		: in std_logic;
            wrreq		: in std_logic;
            q		    : out std_logic_vector(15 downto 0);
            rdempty		: out std_logic;
            rdusedw		: out std_logic_vector(8 downto 0);
            wrusedw		: out std_logic_vector(7 downto 0)
        );
    end component;

    component Master_Controller is
        port (
            data:		        out std_logic_vector(31 downto 0);
            wrusedw:		    in std_logic_vector(7 downto 0);
            wrreq:		        out std_logic;

            stop:               in std_logic;
            get_buffer_addr:    out std_logic;
            buffer_info:        in std_logic_vector(31 downto 0);
            buffer_addr_valid:  in std_logic;
            synchronized:       in std_logic;
            frame_addr_rdy:     in std_logic;

            -- avalon master connections
            AM_Add:     out std_logic_vector(31 downto 0);
            AM_BC:      out std_logic_vector(5 downto 0);
            AM_BE:      out std_logic_vector(3 downto 0);
            AM_Rd:      out std_logic;
            AM_RdDtVld: in std_logic;
            AM_RdData:  in std_logic_vector(31 downto 0);
            AM_WaitRq:  in std_logic;

            clk:        in std_logic;
            nReset:     in std_logic
        );
    end component;

    component Registers is
        port (
            command_data:       out std_logic_vector(15 downto 0);
            Received_data:      out std_logic;
            writing_command:    out std_logic;
            listening_command:  in std_logic;
            send_IRQ:           in std_logic;

            get_buffer_addr:    in std_logic;
            buffer_info:        out std_logic_vector(31 downto 0);
            buffer_addr_valid:  out std_logic;
            synchronized:       out std_logic;
            start:              out std_logic;
            frame_addr_rdy:     out std_logic;

            -- avalon slave connections
            Clk:        in std_logic;
            nReset:     in std_logic;
            AS_add:     in std_logic_vector(3 downto 0);
            AS_CS:      in std_logic;
            AS_wr:      in std_logic;
            AS_WData:   in std_logic_vector(31 downto 0);
            AS_BE:      in std_logic_vector(3 downto 0);
            AS_Rd:      in std_logic;
            AS_RData:   out std_logic_vector(31 downto 0);
            AS_IRQ:     out std_logic;
            AS_WaitRq:  out std_logic
        );
    end component;

    component LCD_Control is
        port (
            nReset:             in std_logic;
            clk:                in std_logic;

            q:		            in std_logic_vector(15 downto 0);
            rdempty:		    in std_logic;
            rdusedw:		    in std_logic_vector(8 downto 0);
            rdreq:		        out std_logic;
            stop:               out std_logic;

            command_data:       in std_logic_vector(15 downto 0);
            Received_data:      in std_logic;
            writing_command:    in std_logic;
            start:               in std_logic;
            listening_command:  out std_logic;
            send_IRQ:           out std_logic;

            LCD_ON:             out std_logic;
            REST_N:             out std_logic;
            CS_N:               out std_logic;
            RS:                 out std_logic;
            WR_N:               out std_logic;
            RD_N:               out std_logic;
            D:                  out std_logic_vector(15 downto 0)
        );
    end component;

begin
    -- map component
    DMAFifo: fifo_lcd
    port map(
        data => data,
		rdclk => Clk,
		rdreq => rdreq,
		wrclk => Clk,
		wrreq => wrreq,
		q => q,
		rdempty => rdempty,
		rdusedw => rdusedw,
		wrusedw => wrusedw
    );

    MstrController: Master_Controller
    port map(
        data => data,
        wrusedw => wrusedw,
        wrreq => wrreq,

        stop => stop,
        get_buffer_addr => get_buffer_addr,
        buffer_info => buffer_info,
        buffer_addr_valid => buffer_addr_valid,
        synchronized => synchronized,
        frame_addr_rdy => frame_addr_rdy,

        -- avalon master map
        AM_Add => AM_Add,
        AM_BC => AM_BC,
        AM_BE => AM_BE,
        AM_Rd => AM_Rd,
        AM_RdDtVld => AM_RdDtVld,
        AM_RdData => AM_RdData,
        AM_WaitRq => AM_WaitRq,

        nReset =>nReset,
        clk => clk
    );

    Regstrs: Registers
    port map(
        command_data => command_data,
        Received_data => Received_data,
        writing_command => writing_command,
        listening_command => listening_command,
        send_IRQ => send_IRQ,

        get_buffer_addr => get_buffer_addr,
        buffer_info => buffer_info,
        buffer_addr_valid => buffer_addr_valid,
        synchronized => synchronized,
        start => start,
        frame_addr_rdy => frame_addr_rdy,

        -- avalon slave connections
        Clk => Clk,
        nReset => nReset,
        AS_add => AS_add,
        AS_CS => AS_CS,
        AS_wr => AS_wr,
        AS_WData => AS_WData,
        AS_BE => AS_BE,
        AS_Rd => AS_Rd,
        AS_RData => AS_RData,
        AS_IRQ => AS_IRQ,
        AS_WaitRq => AS_WaitRq

    );

    LCD_Ctrl: LCD_Control
    port map(
        nReset => nReset,
        clk => clk,

        q => q,
        rdempty => rdempty,
        rdusedw => rdusedw,
        rdreq => rdreq,
        stop => stop,

        command_data => command_data,
        Received_data => Received_data,
        writing_command => writing_command,
        start => start,
        listening_command => listening_command,
        send_IRQ => send_IRQ,

        LCD_ON => LCD_ON,
        REST_N => REST_N,
        CS_N => CS_N,
        RS => RS,
        WR_N => WR_N,
        RD_N => RD_N,
        D => D
    );

end comp;
