library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library unisim;
use unisim.vcomponents.all;

entity fx2lp_interface_top is
  generic(
  -- addresses are:|
  --  * EP8 = "11"
  --  * EP2 = "00"
  constant in_ep_addr:	std_logic_vector(1 downto 0) := "00";
  constant out_ep_addr:	std_logic_vector(1 downto 0) := "11";
  constant port_width: integer := 16
  );
  port(
    -- senales que van y vienen desde y hacia el FX2LP
    fdata   : inout std_logic_vector(port_width-1 downto 0);  -- entrada y salida de datos FIFO
    faddr   : out   std_logic_vector(1 downto 0);           -- canal FIFO
    slrd    : out   std_logic;                              -- senal de lectura
    slwr    : out   std_logic;                              -- senal de escritura

                                                            -- EP2 streaming in (to pc)
    flaga   : in    std_logic;                              -- EP2_full--->write_full_flag
    flagb   : in    std_logic;                              -- EP8_empty-->read_empty_flag
                                                            -- EP8 bulk out (from pc)
    flagc   : in    std_logic;                              -- EP8_full--->read_full_flag
    flagd   : in    std_logic;                              -- EP2_empty-->write_empty_flag
    sloe    : out   std_logic;                              -- senal de habilitacion de salida

    pktend  : out   std_logic;
    -- reloj
      -- se utiliza el reloj que	 provee el EZ-USB-FX2LP
    clk_in  : in    std_logic;                              -- entrada de reloj
	 clk_out	: out   std_logic;										-- salida de reloj

    -- senales que se comunican desde y hacia el sistema
    button  : in    std_logic;                              -- fundamentalmente para sincronizacion..activo en bajo
    send_req: in    std_logic;                              -- pedido de envío de datos
    data_out: out   std_logic_vector(port_width-1 downto 0);
    data_in : in    std_logic_vector(port_width-1 downto 0);
	 
	 -- senales hacia mojo
	 led		: out	std_logic_vector(7 downto 0)

--	 ;avr_tx	: in	std_logic;
--	 avr_rx_busy	: in	std_logic;
--	 avr_rx	: out	std_logic;
--	 cclk	:	in	std_logic
	 );
end fx2lp_interface_top;

architecture fx2lp_interface_arq of fx2lp_interface_top is

	-- declaracion de componentes
	COMPONENT fifo_generator_v9_3
		PORT (
			rst : IN STD_LOGIC;
			wr_clk : IN STD_LOGIC;
			rd_clk : IN STD_LOGIC;
			din : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
			wr_en : IN STD_LOGIC;
			rd_en : IN STD_LOGIC;
			dout : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
			full : OUT STD_LOGIC;
			empty : OUT STD_LOGIC;
			valid : OUT STD_LOGIC
		);
	END COMPONENT;

	component clk_wiz_v3_6
	port(
		CLK_IN1 : in  std_logic;
		CLK_OUT1: out std_logic;
		CLK_OUT2: out std_logic;
		CLK_OUT3: out std_logic;
		CLK_OUT4: out std_logic;
		RESET   : in  std_logic;
		LOCKED  : out std_logic
	);
	end component;

--	COMPONENT avr_interface
--	PORT(
--		clk : IN std_logic;
--		rst : IN std_logic;
--		cclk : IN std_logic;
--		spi_mosi : IN std_logic;
--		spi_sck : IN std_logic;
--		spi_ss : IN std_logic;
--		rx : IN std_logic;
--		channel : IN std_logic_vector(3 downto 0);
--		tx_data : IN std_logic_vector(7 downto 0);
--		new_tx_data : IN std_logic;
--		tx_block : IN std_logic;          
--		spi_miso : OUT std_logic;
--		spi_channel : OUT std_logic_vector(3 downto 0);
--		tx : OUT std_logic;
--		new_sample : OUT std_logic;
--		sample : OUT std_logic_vector(9 downto 0);
--		sample_channel : OUT std_logic_vector(3 downto 0);
--		tx_busy : OUT std_logic;
--		rx_data : OUT std_logic_vector(7 downto 0);
--		new_rx_data : OUT std_logic
--		);
--	END COMPONENT;

	-- declaracion de segnales
	-- relojes
		-- reloj usado en el sistema
	signal sys_clk													: std_logic := '0';
		-- salidas de pll
	signal pll_0, pll_90, pll_180, pll_270					: std_logic := '0';
	signal locked													: std_logic := '0';

	-- cables hacia la interfaz
	signal slwr_int, slrd_int, sloe_int						: std_logic := '1';
	signal pktend_int												: std_logic := '1';
	signal faddr_int												: std_logic_vector(1 downto 0) := "00";
	signal fdata_out, fdata_in									: std_logic_vector(port_width-1 downto 0);
	signal read_empty_flag, read_full_flag					: std_logic := '0';
	signal write_empty_flag, write_full_flag				: std_logic := '0';

	-- cables de dudosa utilidad
	signal push_int, pop_int									: std_logic := '0';
	signal write_req												: std_logic;

--	-- cables de un registro, por las dudas
--	signal d_reg, q_reg											: std_logic_vector(port_width-1 downto 0);
--	signal c_reg, rst_reg, ce_reg								: std_logic;
	--cables ffjk
	signal q, q2													: std_logic := '1';

	-- cables necesarios para la memoria fifo
	signal fifo_full												: std_logic;
	signal fifo_empty												: std_logic;
	signal wr_en, rd_en											: std_logic;
	signal valid													: std_logic;
	signal dout														: std_logic_vector(port_width-1 downto 0);

	-- segnales de sistema
		--init
	signal reset													: std_logic := '0';
		--para depuracion
	signal debug_clk												: std_logic := '0';
--	signal counter													: std_logic_vector(15 downto 0) := x"0000";
--	signal checksum												: std_logic_vector(15 downto 0) := x"0000";
		--temporizaciones
	signal count3													: natural range 0 to 4 := 0;
	signal count2													: natural range 0 to 3 := 0;
	signal cont														: natural range 0 to 16777215 := 10000000;
	signal rst_cont												: natural range 0 to 1023 := 1023;
	signal trig3, trig2											: std_logic := '0';

	-- Maquinas de Estados: xc6slx9-2tqg144
		--maquina de estados de la interfaz
	type if_fsm is
	(
		idle,
		read_addr, read_no_empty, read_read,
		write_addr, write_no_full, write_write, write_end
	);
	signal curr_state, next_state								: if_fsm := idle;

	--debug
	--signal num_state												: std_logic_vector(3 downto 0) := x"0";
	--debug
	
	type fifo_fsm is
	(
		idle, fifo_wren, fifo_nwren
	);
	signal fifo_wr:	fifo_fsm := idle;
	signal fifo_wr_next:	fifo_fsm := idle;
	
	type avr_fsm is
	(
		idle, read_en, avr_send
	);
	signal serial_send:	avr_fsm := idle;
	signal serial_send_next: avr_fsm := idle;
	
-- comunicacion avr
--	signal tx_data	: std_logic_vector(7 downto 0);
	signal new_tx_data:	std_logic;
--	signal tx_busy: std_logic;
	
	begin

--	with curr_state select
--		num_state <= 	"1111" when idle,
--							"0101" when read_addr,
--							"0110" when read_no_empty,
--							"0111" when read_read,
--							"0001" when write_addr,
--							"0010" when write_no_full,
--							"0011" when write_write,
--							"0000" when write_end;
	--debuggin leds
		-- fisically connected. Don't comment!!!
	led(7 downto 1) <= (others => '0');
	led(0) <= fifo_empty;
	
	oddr_y : ODDR2 	                                           -- clk out buffer
	port map
	(
		D0 	=> '1',
		D1 	=> '0',
		CE 	=> '1',
		C0	=> pll_180,
		C1	=> (not pll_180),
		R  	=> '0',
		S  	=> '0',
		Q  	=> clk_out
	);

	--instanciaciones
		--fifo
	fifo : fifo_generator_v9_3
	  PORT MAP (
		 rst => not reset,
		 wr_clk => sys_clk,
		 rd_clk => sys_clk,
		 din => fdata_in,
		 wr_en => wr_en,
		 rd_en => rd_en,
		 dout => dout,
		 full => fifo_full,
		 empty => fifo_empty,
		 valid => valid
	  );
	  
	pll : clk_wiz_v3_6 
		port map(
			CLK_IN1   => clk_in,
			CLK_OUT1  => pll_0,
			CLK_OUT2  => pll_90,
			CLK_OUT3  => pll_180,
			CLK_OUT4  => pll_270,
			RESET     => '0',
			LOCKED    => locked
		);

--	-- com mojo
--	inst_avr_interface: avr_interface PORT MAP(
--		clk => sys_clk,
--		rst => '0',--not reset,
--		cclk => cclk,
--		spi_mosi => '0',
--		spi_sck => '0',
--		spi_ss => '0',
--		tx => avr_rx,
--		rx => avr_tx,
--		channel => "0000",
--		tx_data => tx_data,
--		new_tx_data => new_tx_data,
--		tx_busy => tx_busy,
--		tx_block => avr_rx_busy
--	);

	write_req <= not fifo_empty;
	-- reloj
	sys_clk <= pll_0;

	--conexiones de segnales internas hacia el exterior
	slwr   <= slwr_int;
	slrd   <= slrd_int;
	sloe   <= sloe_int;
	faddr  <= faddr_int;
	pktend <= pktend_int;

	write_full_flag  <= flaga;
	write_empty_flag  <= flagd;
	read_full_flag  <= flagc;
	read_empty_flag  <= flagb;

--	with curr_state select
--		write_req <= '1' when read_read,
--						 '0' when write_end,
--						 write_req when others;

--	write_req <= not fifo_empty;
--	write_req <= '1';
--	tx_data(0) <= dout(0);
--	tx_data(1) <= dout(1);
--	tx_data(2) <= dout(2);
--	tx_data(3) <= dout(3);
--	tx_data(4) <= dout(4);
--	tx_data(5) <= dout(5);
--	tx_data(6) <= dout(6);
--	tx_data(7) <= dout(7);
	
	reset <= '1' when rst_cont = 0 else '0';
	
	-- control signaling
	with curr_state select
		faddr_int <=	out_ep_addr when read_addr | read_no_empty | read_read,-- | idle,--edwin,
							in_ep_addr  when write_addr | write_no_full | write_write | write_end,
							(others => 'Z') when others;

	slwr_int <=	'0' when next_state = write_write else
					'1';

	slrd_int <= '0' when curr_state = read_no_empty else
					'1';

	pktend_int <= (read_empty_flag or write_req);
				
	with curr_state select
		sloe_int <=	'0' when read_read | read_no_empty,
						'1' when others;

-- debug
--	fdata_out(15 downto 8) <= counter(7 downto 0);
--	fdata_out(7 downto 0) <= counter(15 downto 8);
-- debug

	with curr_state select
					--dout->fdata_out
		fdata <=	dout        when write_no_full | write_write | write_end | write_addr,
					(others => 'Z')  when others;

--	with curr_state select
--					--dout->fdata_out
--		fdata(15 downto 8) <=	dout        when write_no_full | write_write | write_end | write_addr,
--					(others => 'Z')  when others;
--
--	with curr_state select
--					--dout->fdata_out
--		fdata(7 downto 0) <=	dout        when write_no_full | write_write | write_end | write_addr,
--					(others => 'Z')  when others;

	with curr_state select
		fdata_in <=	fdata     when read_no_empty | read_read | read_addr,
						fdata_in  when others;
	--              (others => '0');

	-- fifo segnales
	wr_en <= '1' when fifo_wr = fifo_wren else '0';

	rd_en <= '1' when serial_send = read_en else '0';
	
	--avr segnales
	new_tx_data <= '1' when serial_send = avr_send else '0';

	-- Implementacion de las maquinas de estado de la interfaz
--	interfaz_fsm: process(curr_state, write_full_flag, read_empty_flag, write_req,valid)
	interfaz_fsm: process(curr_state, write_full_flag, read_empty_flag, write_req)
	begin
		case curr_state is
			when idle =>
				if read_empty_flag = '1' then
					next_state <= read_addr;
				elsif write_req = '1' then
					if write_full_flag = '1' then
						next_state <= write_addr;
					else
						next_state <= idle;
					end if;
				else
					next_state <= idle;
				end if;

			when read_addr =>
					next_state <= read_no_empty;

			when read_no_empty =>
				next_state <= read_read;

			when read_read =>
					next_state <= idle;

			when write_addr =>
					next_state <= write_no_full;

			when write_no_full =>
				next_state <= write_write;

			when write_write =>
				next_state <= write_end;
								
			when write_end =>
				if write_req = '1' then
					if read_empty_flag = '0' then
						next_state <= write_no_full;
					else
						next_state <= idle;
					end if;
				else
					next_state <= idle;
				end if;

			when others =>
				next_state <= idle;
			end case;
		end process interfaz_fsm;

	-- maquina de estados avr serie
--	read_fifo_fsm : process(serial_send, fifo_empty, slwr_int, valid)
	read_fifo_fsm : process(serial_send, fifo_empty, slwr_int)
	begin
		case serial_send is
			when idle =>
				if slwr_int = '0' then
					if fifo_empty ='0' then
						serial_send_next <= read_en;
					else
						serial_send_next <= idle;
					end if;
				else
					serial_send_next <= idle;
				end if;
					
			when read_en =>
--				serial_send_next <= idle;
				serial_send_next <= avr_send;
			
			when avr_send =>
				if slwr_int ='1' then
					serial_send_next <= idle;
				end if;
				
			when others =>
				serial_send_next <= idle;
		end case;
	end process read_fifo_fsm;

	-- maquina de estados escritura fifo
	write_fifo_fsm: process(fifo_wr,slrd_int,fifo_full)
	begin
		case fifo_wr is
			when idle =>
				if slrd_int = '0' then
					if fifo_full = '0' then
						fifo_wr_next <= fifo_wren;
					else
						fifo_wr_next <= idle;
					end if;
				else
					fifo_wr_next <= idle;
				end if;
			
			when fifo_wren =>
--				fifo_wr_next <= idle;
				fifo_wr_next <= fifo_nwren;
				
			when fifo_nwren =>
				if slrd_int = '1' then
				fifo_wr_next <= idle;
				end if;
				
			when others =>
				fifo_wr_next <= idle;
		end case;
	end process write_fifo_fsm;
	
--	--flip-flop control
--	jkff: process(slrd_int, wr_en)
--	begin
--		if q = '1' then
--			if slrd_int = '0' then
--				q <= '0';
--			else
--				q <= q;
--			end if;
--		else
--			if wr_en = '0' then
--				q <= '1';
--			else
--				q <= q;
--			end if;
--		end if;
--	end process jkff;
--	
--	jkff2: process(slwr_int, rd_en)
--	begin
--		if q2 = '1' then
--			if slwr_int = '0' then
--				q2 <= '0';
--			else
--				q2 <= q2;
--			end if;
--		else
--			if rd_en = '0' then
--				q2 <= '1';
--			else
--				q2 <= q2;
--			end if;
--		end if;
--	end process jkff2;
	-- temporizaciones

	counter3: process(sys_clk, reset, trig3)
	begin
		if reset = '0' then
			count3 <= 0;
		elsif rising_edge(sys_clk) then
			if count3 > 0 then
				count3 <= count3 - 1;
			elsif trig3 = '1' then
				count3 <= 4;
			end if;
		end if;
	end process counter3;

	trig3 <= '1' when (next_state = write_write) else '0';

	counter2: process(sys_clk, reset, trig2)
	begin
		if reset = '0' then
			count2 <= 0;
		elsif rising_edge(sys_clk)then
			if count2 > 0 then
				count2 <= count2 - 1;
			elsif trig2 = '1' then
				count2 <= 3;
			end if;
		end if;
	end process counter2;
		
	with next_state select
		trig2 <=	'1' when read_no_empty | read_read | write_no_full | write_end,
					'0' when others;

	 -- reloj fsm
	global_fsm_clk: process (sys_clk, reset)
	begin
		if reset = '0' then
			curr_state <= idle;
			serial_send <= idle;
			fifo_wr <= idle;
		elsif rising_edge(sys_clk) then
			serial_send <= serial_send_next;
			fifo_wr <= fifo_wr_next;
			if count2 = 0 and count3 = 0 then
				curr_state <= next_state;
			end if;
		end if;
	end process global_fsm_clk;

--	reloj_lento: process(pll_0)
--	begin
--		if(rising_edge(pll_0))then
--			cont <= cont - 1;
--			if cont = 0 then
--				cont <= 10000000;
--				debug_clk <= not debug_clk;
--			end if;
--		end if;
--	end process reloj_lento;

	init_rst: process(sys_clk)
	begin
		if rst_cont /= 0 then
			if rising_edge(sys_clk) then
				rst_cont <= rst_cont - 1;
			end if;
		end if;
	end process init_rst;
	
--	sum: process(curr_state, push_int)
--	variable suma : integer range 0 to 65535 := 0;
--	begin
--		if curr_state = write_addr then
--			checksum <= x"0000";
--		elsif rising_edge(push_int) then
--			checksum <= std_logic_vector(unsigned(checksum) + unsigned(fdata_out(7 downto 0)));
--			checksum <= std_logic_vector(unsigned(checksum) + unsigned(fdata_out(15 downto 8)));
--		end if;
--	end process sum;
--	
	-- debug
--	contador_grande: process(button, pop_int)
--	begin
--		if button = '0' then
--			counter <= x"0000";
--		elsif falling_edge(pop_int) then
--			counter <= std_logic_vector(unsigned(counter) + 1);
--		end if;
--	end process contador_grande;
	-- debug

end fx2lp_interface_arq;
