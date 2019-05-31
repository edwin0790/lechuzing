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
	 clk_out	: out   std_logic;										-- salida de reloj
	 
	 -- senales desde hacia mojo
    clk_in  : in    std_logic;                              -- entrada de reloj
    button  : in    std_logic;                              -- activo en bajo
	 led		: out	std_logic_vector(7 downto 0)
	 
	 );
end fx2lp_interface_top;

architecture fx2lp_interface_arq of fx2lp_interface_top is

	-- declaracion de componentes
	COMPONENT fx2lp_interface
	GENERIC(
		constant in_ep_addr:	std_logic_vector(1 downto 0) := "00";
		constant out_ep_addr:std_logic_vector(1 downto 0) := "11";
		constant port_width: integer := 16
	);
	PORT(
		clk : IN std_logic;
		reset : IN std_logic;
		flaga : IN std_logic;
		flagb : IN std_logic;
		flagc : IN std_logic;
		flagd : IN std_logic;
		send_req : IN std_logic;
		data_to_tx : IN std_logic_vector(15 downto 0);    
		fdata : INOUT std_logic_vector(15 downto 0);      
		faddr : OUT std_logic_vector(1 downto 0);
		slrd : OUT std_logic;
		slwr : OUT std_logic;
		sloe : OUT std_logic;
		pktend : OUT std_logic;
		rx_data : OUT std_logic_vector(15 downto 0)
		);
	END COMPONENT;


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

	-- declaracion de segnales
	-- relojes
		-- reloj usado en el sistema
	signal sys_clk	: std_logic := '0';
		-- salidas de pll
	signal pll_0	: std_logic := '0';
	signal pll_90	: std_logic := '0';
	signal pll_180	: std_logic := '0';
	signal pll_270	: std_logic := '0';
	signal locked	: std_logic := '0';

	-- cables de utilidad
	signal write_req	: std_logic := '0';
	signal slwr_sig	: std_logic := '0';
	signal slrd_sig	: std_logic := '0';

--	-- cables para registro de eco
--	signal d_reg, q_reg											: std_logic_vector(port_width-1 downto 0);
--	signal c_reg, rst_reg, ce_reg								: std_logic;

	-- cables necesarios para la memoria fifo
	signal fifo_full	: std_logic;
	signal fifo_empty	: std_logic;
	signal wr_en	: std_logic;
	signal rd_en	: std_logic;
	signal valid	: std_logic;
	signal dout	: std_logic_vector(port_width-1 downto 0);
	signal din	: std_logic_vector(port_width-1 downto 0);
	-- segnales de sistema
		--init
	signal reset	: std_logic := '0';

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
	
	type fifo_wr_states is
	(
		idle, fifo_wren, fifo_nwren
	);
	signal fifo_wr_cst:	fifo_wr_states := idle;
	signal fifo_wr_nst:	fifo_wr_states := idle;
	
	type fifo_rd_states is
	(
		idle, fifo_rden, fifo_nrden
	);
	signal fifo_rd_cst:	fifo_rd_states := idle;
	signal fifo_rd_nst:	fifo_rd_states := idle;
		
	begin

	--debuggin leds
		-- fisically connected. Don't comment!!!
	led(7 downto 0) <= (others => '0');
	
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
	-- interfaz
	interface: fx2lp_interface PORT MAP(
		clk => sys_clk,
		reset => reset,
		fdata => fdata,
		faddr => faddr,
		slrd => slrd_sig,
		slwr => slwr_sig,
		flaga => flaga,
		flagb => flagb,
		flagc => flagc,
		flagd => flagd,
		sloe => sloe,
		pktend => pktend,
		send_req => write_req,
		rx_data => din,
		data_to_tx => dout
	);

	--fifo
	fifo : fifo_generator_v9_3
	  PORT MAP (
		 rst => not reset,
		 wr_clk => sys_clk,
		 rd_clk => sys_clk,
		 din => din,
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

	--REVISAR TODO ESTO
	wr_req_ff : process (sys_clk, slwr_sig, fifo_empty)
	begin
		if rising_edge(sys_clk) then
			if fifo_empty = '0' then
				write_req <= '1';
			else
				if slwr_sig = '1' then
					write_req <= '0';
				else
					write_req <= write_req;
				end if;
			end if;
		end if;
	end process wr_req_ff;
	--REVISAR TODO ESTO
	
	-- reloj
	sys_clk <= pll_0;

	--conexiones de segnales internas hacia el exterior
	slwr   <= slwr_sig;
	slrd   <= slrd_sig;
--	sloe   <= sloe_int;
--	faddr  <= faddr_int;
--	pktend <= pktend_int;
--
--	write_full_flag  <= flaga;
--	write_empty_flag  <= flagd;
--	read_full_flag  <= flagc;
--	read_empty_flag  <= flagb;
	
	reset <= '1' when rst_cont = 0 else '0';
	
	-- control signaling
--	with curr_state select
--		faddr_int <=	out_ep_addr when read_addr | read_no_empty | read_read,-- | idle,--edwin,
--							in_ep_addr  when write_addr | write_no_full | write_write | write_end,
--							(others => 'Z') when others;
--
--	slwr_int <=	'0' when next_state = write_write else
--					'1';
--
--	slrd_int <= '0' when curr_state = read_no_empty else
--					'1';
--
--	pktend_int <= (read_empty_flag or write_req);
--				
--	with curr_state select
----		sloe_int <=	'0' when read_read | read_no_empty,
--		sloe_int <=	'0' when read_addr | read_read | read_no_empty,
--						'1' when others;
--
---- debug
----	fdata_out(15 downto 8) <= counter(7 downto 0);
----	fdata_out(7 downto 0) <= counter(15 downto 8);
---- debug
--
--	with curr_state select
--					--dout->fdata_out
--		fdata <=	dout        when write_no_full | write_write | write_end | write_addr,
--					(others => 'Z')  when others;
--
--	with curr_state select
--		fdata_in <=	fdata     when read_no_empty | read_read | read_addr,
--						fdata_in  when others;

	-- fifo segnales
	wr_en <= '1' when fifo_wr_cst = fifo_wren else '0';

	rd_en <= '1' when fifo_rd_cst = fifo_rden else '0';

	-- Implementacion de las maquinas de estado de la interfaz
--	interfaz_fsm: process(curr_state, write_full_flag, read_empty_flag, write_req)
--	begin
--		case curr_state is
--			when idle =>
--				if read_empty_flag = '1' then
--					next_state <= read_addr;
--				elsif write_req = '1' then
--					if write_full_flag = '1' then
--						next_state <= write_addr;
--					else
--						next_state <= idle;
--					end if;
--				else
--					next_state <= idle;
--				end if;
--
--			when read_addr =>
--					next_state <= read_no_empty;
--
--			when read_no_empty =>
--				next_state <= read_read;
--
--			when read_read =>
--				if read_empty_flag = '1' then
--					next_state <= read_addr;
--				else
--					next_state <= idle;
--				end if;
--
--			when write_addr =>
--					next_state <= write_no_full;
--
--			when write_no_full =>
--				next_state <= write_write;
--
--			when write_write =>
--				next_state <= write_end;
--								
--			when write_end =>
--				if write_req = '1' then
--					if read_empty_flag = '0' then
--						next_state <= write_no_full;
--					else
--						next_state <= idle;
--					end if;
--				else
--					next_state <= idle;
--				end if;
--
--			when others =>
--				next_state <= idle;
--			end case;
--		end process interfaz_fsm;
--
	-- maquina de estados de lectura fifo
	read_fifo_fsm : process(fifo_rd_cst, fifo_empty, slwr_sig)
	begin
		case fifo_rd_cst is
			when idle =>
				if slwr_sig = '0' then
					if fifo_empty ='0' then
						fifo_rd_nst <= fifo_rden;
					else
						fifo_rd_nst <= idle;
					end if;
				else
					fifo_rd_nst <= idle;
				end if;
					
			when fifo_rden =>
				fifo_rd_nst <= fifo_nrden;
			
			when fifo_nrden =>
				if slwr_sig ='1' then
					fifo_rd_nst <= idle;
				end if;
				
			when others =>
				fifo_rd_nst <= idle;
		end case;
	end process read_fifo_fsm;

	-- maquina de estados escritura fifo
	write_fifo_fsm: process(fifo_wr_cst,slrd_sig,fifo_full)
	begin
		case fifo_wr_cst is
			when idle =>
				if slrd_sig = '0' then
					if fifo_full = '0' then
						fifo_wr_nst <= fifo_wren;
					else
						fifo_wr_nst <= idle;
					end if;
				else
					fifo_wr_nst <= idle;
				end if;
			
			when fifo_wren =>
				fifo_wr_nst <= fifo_nwren;
				
			when fifo_nwren =>
				if slrd_sig = '1' then
				fifo_wr_nst <= idle;
				end if;
				
			when others =>
				fifo_wr_nst <= idle;
		end case;
	end process write_fifo_fsm;
	
	-- temporizaciones
--	counter3: process(sys_clk, reset, trig3)
--	begin
--		if reset = '0' then
--			count3 <= 0;
--		elsif rising_edge(sys_clk) then
--			if count3 > 0 then
--				count3 <= count3 - 1;
--			elsif trig3 = '1' then
--				count3 <= 4;
--			end if;
--		end if;
--	end process counter3;
--
--	trig3 <= '1' when (next_state = write_write) else '0';
--
--	counter2: process(sys_clk, reset, trig2)
--	begin
--		if reset = '0' then
--			count2 <= 0;
--		elsif rising_edge(sys_clk)then
--			if count2 > 0 then
--				count2 <= count2 - 1;
--			elsif trig2 = '1' then
--				count2 <= 3;
--			end if;
--		end if;
--	end process counter2;
--		
--	with next_state select
--		trig2 <=	'1' when read_no_empty | read_read | write_no_full | write_end,
--					'0' when others;

	 -- reloj fsm
	global_fsm_clk: process (sys_clk, reset)
	begin
		if reset = '0' then
--			curr_state <= idle;
			fifo_rd_cst <= idle;
			fifo_wr_cst <= idle;
		elsif rising_edge(sys_clk) then
			fifo_rd_cst <= fifo_rd_nst;
			fifo_wr_cst <= fifo_wr_nst;
--			if count2 = 0 and count3 = 0 then
--				curr_state <= next_state;
--			end if;
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

end fx2lp_interface_arq;
