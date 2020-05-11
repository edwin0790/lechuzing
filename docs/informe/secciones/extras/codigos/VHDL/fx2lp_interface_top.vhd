library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library unisim;
use unisim.vcomponents.all;

entity fx2lp_interface_top is
	generic(
		-- direcciones EP:
		--  * EP8 = "11"
		--  * EP2 = "00"
		constant ent_ep_addr:std_logic_vector(1 downto 0) := "00";
		constant sal_ep_addr:std_logic_vector(1 downto 0) := "11";
		constant ancho_bus	:integer := 16
	);
	port(
		-- senales que van y vienen desde y hacia el FX2LP
		fdata   :inout std_logic_vector(ancho_bus-1 downto 0);
			-- entrada y salida de datos FIFO
		faddr   :out   std_logic_vector(1 downto 0);           
			-- canal FIFO
		slrd		:out	std_logic;-- senal de lectura
		slwr		:out	std_logic;-- senal de escritura
		flaga		:in		std_logic;-- EP2_full--->esc_flag_lleno
		flagb		:in		std_logic;-- EP8_empty-->lec_flag_vacio
		flagc		:in		std_logic;-- EP8_full--->lec_flag_lleno
		flagd		:in		std_logic;-- EP2_empty-->esc_flag_vacio
		sloe		:out	std_logic;-- senal de habilitacion de salida
		pktend		:out	std_logic;
		-- reloj
		reloj_sal	:out	std_logic;-- salida de reloj
		-- senales desde y hacia mojo
		reloj_ent	:in		std_logic;-- entrada de reloj
		pulsador	:in		std_logic;-- activo en bajo
		led			:out	std_logic_vector(7 downto 0)

	);
end fx2lp_interface_top;

architecture fx2lp_interface_arq of fx2lp_interface_top is

	-- declaracion de componentes
	COMPONENT fx2lp_interface
		GENERIC(
			constant ent_ep_addr:std_logic_vector(1 downto 0);
			constant sal_ep_addr:std_logic_vector(1 downto 0);
			constant ancho_bus	:integer
		);
		PORT(
			reloj : IN std_logic;
			reset : IN std_logic;
			enviar_datos : IN std_logic;
			dato_a_enviar : IN std_logic_vector(15 downto 0);    
			flaga : IN std_logic;
			flagb : IN std_logic;
			flagc : IN std_logic;
			flagd : IN std_logic;
			fdata : INOUT std_logic_vector(15 downto 0);      
			dato_recibido : OUT std_logic_vector(15 downto 0);
			faddr : OUT std_logic_vector(1 downto 0);
			slrd : OUT std_logic;
			slwr : OUT std_logic;
			sloe : OUT std_logic;
			pktend : OUT std_logic
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
	signal reloj_sistema:std_logic := '0';
			-- salidas de pll
	signal pll_50		:std_logic := '0';
	signal pll_48		:std_logic := '0';
	signal pll_40		:std_logic := '0';
	signal pll_35		:std_logic := '0';
	signal locked		:std_logic := '0';

	-- cables de utilidad
	signal enviar_datos	:std_logic := '0';
	signal slwr_sig		:std_logic := '0';
	signal slrd_sig		:std_logic := '0';

	-- cables necesarios para la memoria fifo
	signal fifo_llena	:std_logic;
	signal fifo_vacia	:std_logic;
	signal wr_en		:std_logic;
	signal rd_en		:std_logic;
	signal valid		:std_logic;
	signal dout			:std_logic_vector(ancho_bus-1 downto 0);
	signal din			:std_logic_vector(ancho_bus-1 downto 0);
	-- segnales de sistema
		--init
	signal reset	:std_logic := '0';

	signal rst_cont	:natural range 0 to 1023 := 1023;

	-- Maquinas de Estados: xc6slx9-2tqg144	
	type fifo_esc_estados is(
		inicio, hab, dehab
	);
	signal fifo_esc_act:	fifo_esc_estados := inicio;
	signal fifo_esc_prox:	fifo_esc_estados := inicio;

	type fifo_lec_estados is(
		inicio, hab, dehab
	);
	signal fifo_lec_act:	fifo_lec_estados := inicio;
	signal fifo_lec_prox:	fifo_lec_estados := inicio;

begin

	-- leds. Se conectan en la implementación física. 
	-- NO COMENTAR!!!
	led(7 downto 0) <= (others => '0');

	oddr_y : ODDR2	-- buffer para reloj salida 
	port map(
		D0 	=> '1',
		D1 	=> '0',
		CE 	=> '1',
		C0	=> pll_50,
		C1	=> (not pll_50),
		R  	=> '0',
		S  	=> '0',
		Q  	=> reloj_sal
	);

	--instanciaciones
	-- interfaz
	interface: fx2lp_interface PORT MAP(
		reloj => reloj_sistema,
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
		enviar_datos => enviar_datos,
		dato_recibido => din,
		dato_a_enviar => dout
	);

	--fifo
	fifo : fifo_generator_v9_3
	PORT MAP(
		rst => not reset,
		clk => reloj_sistema,
		din => din,
		wr_en => wr_en,
		rd_en => rd_en,
		dout => dout,
		full => fifo_llena,
		empty => fifo_vacia,
		valid => valid
	);

	pll : clk_wiz_v3_6 
	port map(
		CLK_IN1   => reloj_ent,
		CLK_OUT1  => pll_50,
		CLK_OUT2  => pll_48,
		CLK_OUT3  => pll_40,
		CLK_OUT4  => pll_35,
		RESET     => '0',
		LOCKED    => locked
	);

	env_sol_proc : process (reloj_sistema, slwr_sig, fifo_vacia)
	begin
		if rising_edge(reloj_sistema) then
			if fifo_vacia = '0' then
				enviar_datos <= '1';
			else
				if slwr_sig = '1' then
					enviar_datos <= '0';
				else
					enviar_datos <= enviar_datos;
				end if;
			end if;
		end if;
	end process env_dat_proc;

	-- reloj
	reloj_sistema <= pll_48;

	--conexiones de segnales internas hacia el exterior
	slwr <= slwr_sig;
	slrd <= slrd_sig;

	reset <=	'1' when rst_cont = 0 else
				'1' when pulsador = '0' else '0';

	-- fifo segnales
	wr_en <= '1' when fifo_esc_act = dehab else '0';

	rd_en <= '1' when fifo_lec_act = hab else '0';

	-- maquina de estados de lectura fifo
	leer_fifo_mef : process(fifo_lec_act, fifo_vacia, slwr_sig)
	begin
		case fifo_lec_act is
			when inicio =>
				if slwr_sig = '0' then
					if fifo_vacia ='0' then
						fifo_lec_prox <= hab;
					else
						fifo_lec_prox <= inicio;
					end if;
				else
					fifo_lec_prox <= inicio;
				end if;

			when hab =>
				fifo_lec_prox <= dehab;

			when dehab =>
				if slwr_sig ='1' then
					fifo_lec_prox <= inicio;
				end if;

			when others =>
				fifo_lec_prox <= inicio;
		end case;
	end process leer_fifo_mef;

	-- maquina de estados escritura fifo
	escr_fifo_mef: process(fifo_esc_act,slrd_sig,fifo_llena)
	begin
		case fifo_esc_act is
			when inicio =>
				if slrd_sig = '0' then
					if fifo_llena = '0' then
						fifo_esc_prox <= hab;
					else
						fifo_esc_prox <= inicio;
					end if;
				else
					fifo_esc_prox <= inicio;
				end if;

			when hab =>
				fifo_esc_prox <= dehab;

			when dehab =>
				if slrd_sig = '1' then
					fifo_esc_prox <= inicio;
				end if;

			when others =>
				fifo_esc_prox <= inicio;
		end case;
	end process escr_fifo_mef;

	reloj_mef_global: process (reloj_sistema, reset)
	begin
		if reset = '0' then
			fifo_lec_act <= inicio;
			fifo_esc_act <= inicio;
		elsif rising_edge(reloj_sistema) then
			fifo_lec_act <= fifo_lec_prox;
			fifo_esc_act <= fifo_esc_prox;
		end if;
	end process reloj_mef_global;

	inic_rst: process(reloj_sistema)
	begin
		if rst_cont /= 0 then
			if rising_edge(reloj_sistema) then
				rst_cont <= rst_cont - 1;
			end if;
		end if;
	end process inic_rst;
end fx2lp_interface_arq;
