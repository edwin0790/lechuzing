library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity fx2lp_interfaz is
	generic(
		constant ent_ep_addr:	std_logic_vector(1 downto 0) := "00";
		constant sal_ep_addr:	std_logic_vector(1 downto 0) := "11";
		constant ancho_bus: integer := 16
	);
	port(
	-- desde y hacia el sistema
		reloj		:in	std_logic;
		reset		:in	std_logic;
		enviar_datos	:in	std_logic;
		dato_recibido	:out	std_logic_vector(ancho_bus-1 downto 0);
		dato_a_enviar	:in	std_logic_vector(ancho_bus-1 downto 0)
	-- desde y hacia la interfaz
		fdata	: inout std_logic_vector(ancho_bus-1 downto 0);
			-- entrada y salida de datos FIFO
		faddr	: out	std_logic_vector(1 downto 0);
			-- canal FIFO
		slrd	: out	std_logic;	-- senal de lectura
		slwr	: out	std_logic;	-- senal de escritura
		flaga	: in	std_logic;	-- EP2_full--->esc_full_flag
		flagb	: in	std_logic;	-- EP8_empty-->lec_empty_flag
		flagc	: in	std_logic;	-- EP8_full--->lec_full_flag
		flagd	: in	std_logic;	-- EP2_empty-->esc_empty_flag
		sloe	: out	std_logic;	-- senal de habilitacion de salida
		pktend	: out	std_logic;
	);
end fx2lp_interfaz;

architecture Behavioral of fx2lp_interfaz is

	signal slwr_int	: std_logic := '1';
	signal slrd_int	: std_logic := '1';
	signal sloe_int	: std_logic := '1';
	signal pktend_int	: std_logic := '1';
	signal faddr_int	: std_logic_vector(1 downto 0) := "ZZ";
	signal fdata_sal	: std_logic_vector(ancho_bus-1 downto 0);
	signal fdata_ent	: std_logic_vector(ancho_bus-1 downto 0);
	signal lec_eflag	: std_logic := '1';
	signal lec_fflag	: std_logic := '1';
	signal esc_eflag	: std_logic := '1';
	signal esc_fflag	: std_logic :=1';

	signal reloj_sist		: std_logic;

	-- segnales de temporizacion
	signal contador3	: natural range 0 to 4 := 0;
	signal contador2	: natural range 0 to 3 := 0;
	signal disp3, disp2	: std_logic := '0';

	-- maquina de estados de la interfaz
	type estados_mef is
	(
		inicio,
		lec_direccion, lectura,
		esc_direccion, escritura
	);
	signal estado_actual, prox_estado	: estados_mef := inicio;

begin
	-- conexion de segnales internas hacia los puertos
	reloj_sist <= reloj;

	slwr   <= slwr_int;
	slrd   <= slrd_int;
	sloe   <= sloe_int;
	faddr  <= faddr_int;
	pktend <= pktend_int;

	esc_fflag  <= not flaga;
	lec_eflag  <= not flagb;

	dato_recibido <= fdata_ent;
	fdata_sal <= dato_a_enviar;
	
	-- segnalizacion
	with estado_actual select
		faddr_int <=	sal_ep_addr when lec_dir | lectura,
				ent_ep_addr  when esc_direccion | escritura,
				(others => 'Z') when others;

	slwr_int <=	'0' when prox_estado = esc_direccion else
					'1';

	slrd_int <= '0' when estado_actual = lec_dir else
					'1';

	pktend_int <= ((not lec_eflag) or enviar_datos);
				
	with estado_actual select
		sloe_int <=	'0' when lectura | lec_dir,
						'1' when others;

	with estado_actual select
					--dout->fdata_sal
		fdata <=	fdata_sal        when escritura | esc_direccion,
					(others => 'Z')  when others;

	with estado_actual select
		fdata_ent <=	fdata     when lectura | lec_dir,
						fdata_ent  when others;
	
	--implementacion de la maquina de estados
	interfaz_mef: process(estado_actual, esc_fflag, lec_eflag, enviar_datos)
	begin
		case estado_actual is
			when inicio =>
				if lec_eflag = '0' then
					prox_estado <= lectura;
				elsif enviar_datos = '1' then
					if esc_fflag = '0' then
						prox_estado <= escritura;
					else
						prox_estado <= inicio;
					end if;
				else
					prox_estado <= inicio;
				end if;

			when lec_dir =>
				prox_estado <= lectura;

			when lectura =>
				if lec_eflag = '0' then
					prox_estado <= lec_dir;
				else
					prox_estado <= inicio;
				end if;

			when esc_direccion =>
				prox_estado <= escritura;
								
			when escritura =>
				if enviar_datos = '1' then
					if lec_eflag = '1' and esc_fflag = '0' then
						prox_estado <= esc_direccion;
					else
						prox_estado <= inicio;
					end if;
				else
					prox_estado <= inicio;
				end if;

			when others =>
				prox_estado <= inicio;
			end case;
		end process interfaz_mef;

	-- temporizaciones
	reloj_mef: process (reloj_sist, reset)
	begin
		if reset = '0' then
			estado_actual <= inicio;
		elsif rising_edge(reloj_sist) then
			if contador2 = 0 and contador3 = 0 then
				estado_actual <= prox_estado;
			end if;
		end if;
	end process reloj_mef;

	tempo3: process(reloj_sist, reset, disp3)
	begin
		if reset = '0' then
			contador3 <= 0;
		elsif rising_edge(reloj_sist) then
			if contador3 > 0 then
				contador3 <= contador3 - 1;
			elsif disp3 = '1' then
				contador3 <= 4;
			end if;
		end if;
	end process tempo3;

	disp3 <= '1' when (prox_estado = esc_direccion) else '0';

	tempo2: process(reloj_sist, reset, disp2)
	begin
		if reset = '0' then
			contador2 <= 0;
		elsif rising_edge(reloj_sist)then
			if contador2 > 0 then
				contador2 <= contador2 - 1;
			elsif disp2 = '1' then
				contador2 <= 3;
			end if;
		end if;
	end process tempo2;
		
	with prox_estado select
		disp2 <=	'1' when lectura | lec_dir | escritura,
					'0' when others;

end Behavioral;

