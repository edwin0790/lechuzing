--------------------------------------------------------------------------------
-- Company: 
-- Engineer:
--
-- Create Date:   19:20:14 03/19/2020
-- Design Name:   
-- Module Name:   G:/Facultad/Trabajo Final/Spartan6/fx2lp_tb.vhd
-- Project Name:  Spartan6
-- Target Device:  
-- Tool versions:  
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: fx2lp_interface
-- 
-- Dependencies:
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--
-- Notes: 
-- This testbench has been automatically generated using types std_logic and
-- std_logic_vector for the ports of the unit under test.  Xilinx recommends
-- that these types always be used for the top-level I/O of a design in order
-- to guarantee that the testbench will bind correctly to the post-implementation 
-- simulation model.
--------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
 
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--USE ieee.numeric_std.ALL;
 
ENTITY fx2lp_tb IS
END fx2lp_tb;
 
ARCHITECTURE behavior OF fx2lp_tb IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
 
    COMPONENT fx2lp_interface
    PORT(
         clk : IN  std_logic;
         reset : IN  std_logic;
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
         send_req : IN  std_logic;
         rx_data : OUT  std_logic_vector(15 downto 0);
         data_to_tx : IN  std_logic_vector(15 downto 0)
        );
    END COMPONENT;
    

   --Inputs
   signal clk : std_logic := '0';
   signal reset : std_logic := '0';
   signal flaga : std_logic := '0';
   signal flagb : std_logic := '0';
   signal flagc : std_logic := '0';
   signal flagd : std_logic := '0';
   signal send_req : std_logic := '0';
   signal data_to_tx : std_logic_vector(15 downto 0) := (others => '0');

	--BiDirs
   signal fdata : std_logic_vector(15 downto 0);

 	--Outputs
   signal faddr : std_logic_vector(1 downto 0);
   signal slrd : std_logic;
   signal slwr : std_logic;
   signal sloe : std_logic;
   signal pktend : std_logic;
   signal rx_data : std_logic_vector(15 downto 0);

   -- Clock period definitions
   constant clk_period : time := 10 ns;
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: fx2lp_interface PORT MAP (
          clk => clk,
          reset => reset,
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
          send_req => send_req,
          rx_data => rx_data,
          data_to_tx => data_to_tx
        );

   -- Clock process definitions
--   clk_process :process
--   begin
--		clk <= '0';
--		wait for clk_period/2;
--		clk <= '1';
--		wait for clk_period/2;
--   end process;
	clk <= not clk after clk_period/2;
	reset <= '0', '1' after 100 ns;
   -- Stimulus process
   stim_proc: process
   begin		
--      reset <= '0';-- hold reset state for 100 ns.
		flaga <= '1';
		flagb <= '0';
		flagc	<=	'1';
		flagd	<= '0';
		send_req <= '0';
		data_to_tx <= (others => 'Z');
		wait until reset = '1';
		
		wait for clk_period*5;	

--		reset <= '1';
		
--      wait for clk_period*10;

      -- insert stimulus here 
		-- operacion de lectura
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
		data_to_tx <= x"abcd";
		send_req <= '1';
		
		--operacion de escritura
		wait until sloe='1';
		fdata <=(others => 'Z');
		wait until slwr='0';

		data_to_tx <= x"392a";
		wait until slwr='0';

		data_to_tx <= x"4444";
		wait until slwr='0';

		data_to_tx <= x"a8b2";
		--interrupcion por prioridad
		flagb <= '1';
		wait until sloe = '0';
		fdata <= x"1515";
		wait until slrd='0';
		flagb <= '0';
		wait until sloe = '1';
		-- operacion de escritura
		data_to_tx <= x"2525";
		fdata <= (others => 'Z');
		wait until slwr = '0';

		data_to_tx <= x"7868";
		wait until slwr = '0';
		--interrupcion por llenado de memoria
		flaga <= '0';
--		wait until slwr = '1';
		--final de operacion escritura
--		send_req <= '1';
      wait for clk_period*10;
		wait;
   end process;

END;
