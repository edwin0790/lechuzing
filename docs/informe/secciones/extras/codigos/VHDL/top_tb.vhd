LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
use ieee.std_logic_unsigned.all;

ENTITY interface_test_bench IS
END interface_test_bench;

ARCHITECTURE behavior OF interface_test_bench IS

	-- Component Declaration for the Unit Under Test (UUT)
	COMPONENT fx2lp_interface_top
		PORT(
			fdata : INOUT  std_logic_vector(15 downto 0);
			faddr : OUT  std_logic_vector(1 downto 0);
			slrd : OUT  std_logic;
			slwr : OUT  std_logic;
			flaga : IN  std_logic;
			flagb : IN  std_logic;
			flagc : IN  std_logic;
			flagd : IN  std_logic;
			sloe : OUT  std_logic;
			pktend : OUT  std_logic;
			reloj_ent : IN  std_logic;
			reloj_sal : OUT  std_logic;
			pulsador : IN  std_logic;
			led : OUT std_logic_vector(7 downto 0)
		);
	END COMPONENT;


	--Inputs
	signal flaga : std_logic := '0';
	signal flagb : std_logic := '0';
	signal flagc : std_logic := '0';
	signal flagd : std_logic := '0';
	signal reloj_ent : std_logic := '0';
	signal pulsador : std_logic := '0';

	--BiDirs
	signal fdata : std_logic_vector(15 downto 0);

	--Outputs
	signal faddr : std_logic_vector(1 downto 0);
	signal slrd : std_logic;
	signal slwr : std_logic;
	signal sloe : std_logic;
	signal pktend : std_logic;
	signal reloj_sal : std_logic;
	signal led : std_logic_vector(7 downto 0);

	-- Clock period definitions
	constant periodo_reloj : time := 21 ns;

	-- Data generator
	signal contador: std_logic_vector(15 downto 0) := x"0000";

BEGIN
	-- Instantiate the Unit Under Test (UUT)
	uut: fx2lp_interface_top PORT MAP (
		fdata => fdata,
		faddr => faddr,
		slrd => slrd,
		slwr => slwr,
		flaga => flaga,
		flagb => flagb,
		flagc => flagc,
		flagd => flagd,
		sloe => sloe,
		pktend => pktend,
		reloj_ent => reloj_ent,
		reloj_sal => reloj_sal,
		pulsador => pulsador,
		led => led			 
	);

	-- Clock process definitions
	ent_reloj_process :process
	begin
		clk_in <= '0';
		wait for periodo_reloj/2;
		clk_in <= '1';
		wait for periodo_reloj/2;
	end process;

	-- Start up reset
	pulsador <= '0', '1' after 100 ns;

	-- estimulos flags. todas activas en bajo
	flags_proc: process
	begin
		flaga <= '1'; -- ep2full
		flagb <= '0'; -- ep8empty
		flagc <= '1'; -- ep8full
		flagd <= '0'; -- ep2empty
		wait for 5 us;

		flagb <= '1';
		wait until counter = x"0100";
		wait until falling_edge(clk_in);

		flagb <= '0';
		wait until fdata = x"00f0";
		flaga <= '0';
		wait until pktend = '0';
		wait;
	end process;

	-- emulador de datos
	data_proc: process(slrd)
	begin
		if pulsador = '0' then
			contador <= x"0000";
		elsif rising_edge(slrd)then
			contador <= contador + 1;
		end if;
	end process;

	with flagb select
		fdata <= contador when '1',(others => 'Z')when others;
END;
