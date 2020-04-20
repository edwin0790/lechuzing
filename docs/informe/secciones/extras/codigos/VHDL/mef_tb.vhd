LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
 
ENTITY mef_tb IS
END mef_tb;
 
ARCHITECTURE behavior OF mef_tb IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
 
    COMPONENT fx2lp_interfaz
    PORT(
		reloj			:in 	std_logic;
		reset			:in 	std_logic;
		enviar_datos	:in 	std_logic;
		dato_recibido	:out	std_logic_vector(15 downto 0);
		dato_a_enviar	:in	 	std_logic_vector(15 downto 0);
		fdata			:inout  std_logic_vector(15 downto 0);
		faddr			:out	std_logic_vector(1 downto 0);
		slrd			:out	std_logic;
		slwr			:out	std_logic;
		flaga			:in		std_logic;
		flagb			:in		std_logic;
		flagc			:in		std_logic;
		flagd			:in		std_logic;
		sloe			:out	std_logic;
		pktend			:out	std_logic
        );
    END COMPONENT;
    

   --Inputs
   signal reloj			:std_logic := '0';
   signal reset			:std_logic := '0';
   signal flaga			:std_logic := '0';
   signal flagb			:std_logic := '0';
   signal flagc			:std_logic := '0';
   signal flagd			:std_logic := '0';
   signal enviar_datos	:std_logic := '0';
   signal dato_a_enviar	:std_logic_vector(15 downto 0) := (others => '0');

	--BiDirs
   signal fdata	:std_logic_vector(15 downto 0);

 	--Outputs
   signal faddr			:std_logic_vector(1 downto 0);
   signal slrd			:std_logic;
   signal slwr			:std_logic;
   signal sloe			:std_logic;
   signal pktend		:std_logic;
   signal dato_recibido	:std_logic_vector(15 downto 0);

   -- Clock period definitions
   constant periodo_reloj : time := 10 ns;
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: fx2lp_interfaz PORT MAP (
          reloj => reloj,
          reset => reset,
          enviar_datos => enviar_datos,
          dato_recibido => dato_recibido,
          dato_a_enviar => dato_a_enviar,
          fdata => fdata,
          faddr => faddr,
          slrd => slrd,
          slwr => slwr,
          flaga => flaga,
          flagb => flagb,
          flagc => flagc,
          flagd => flagd,
          sloe => sloe,
          pktend => pktend
        );

	reloj <= not reloj after periodo_reloj/2;
	reset <= '0', '1' after 100 ns;

   -- Stimulus process
   stim_proc: process
   begin		
		flaga <= '1';
		flagb <= '0';
		flagc	<=	'1';
		flagd	<= '0';
		enviar_datos <= '0';
		dato_a_enviar <= (others => 'Z');
		wait until reset = '1';

		wait for periodo_reloj*5;	

		flagb <= '1';
		wait until sloe = '0';

		fdata <= x"AAAA";
		wait until slrd = '0';	

		fdata <= x"8888";
		wait until slrd ='0';

		fdata <=x"3846";
		wait until slrd = '0';

		--no interrupcion de lectura
		fdata <= x"aaaa";
		flagb <= '0';
		wait until rising_edge(slrd);		
		dato_a_enviar <= x"abcd";
		enviar_datos <= '1';
		
		--operacion de escritura
		wait until sloe='1';
		fdata <=(others => 'Z');
		wait until slwr='0';

		dato_a_enviar <= x"392a";
		wait until slwr='0';

		dato_a_enviar <= x"4444";
		wait until slwr='0';

		dato_a_enviar <= x"a8b2";
		--interrupcion por prioridad
		flagb <= '1';
		wait until sloe = '0';
		fdata <= x"1515";
		wait until slrd='0';
		flagb <= '0';
		wait until sloe = '1';
		-- operacion de escritura
		dato_a_enviar <= x"2525";
		fdata <= (others => 'Z');
		wait until slwr = '0';

		dato_a_enviar <= x"7868";
		wait until slwr = '0';
		--interrupcion por llenado de memoria
		flaga <= '0';
		--final de operacion escritura
      wait for periodo_reloj*10;
		wait;
   end process;
END;
