--------------------------------------------------------------------------------
-- Trabajo Final de Ingeniería Electrónica
-- Universidad Nacional de San Juan
-- Autor: Edwin Barragan
-- Asesores: Cristian Sisterna
--           Martín Perez
--           Marcelo Segura
--
-- Create Date:   14:13:35 07/21/2017
-- Design Name:   FX2LP - FPGA Interface
-- Module Name:   /home/lechuzin/Facultad/Trabajo Final/lechuzing/Cyclon6/interface_test_bench.vhd
-- Project Name:  Cyclon6
-- Target Device:  Cyclon6
-- Tool versions:
-- Description:
--
-- VHDL Test Bench Created by ISE for module: fx2lp_interface_top
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
use ieee.std_logic_unsigned.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--USE ieee.numeric_std.ALL;

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
         clk_in : IN  std_logic;
         clk_out : OUT  std_logic;
         button : IN  std_logic;
         send_req : IN  std_logic;
         data_out : OUT  std_logic_vector(15 downto 0);
         data_in : IN  std_logic_vector(15 downto 0)
        );
    END COMPONENT;


   --Inputs
   signal flaga : std_logic := '0';
   signal flagb : std_logic := '0';
   signal flagc : std_logic := '0';
   signal flagd : std_logic := '0';
   signal clk_in : std_logic := '0';
   signal button : std_logic := '0';
   signal send_req : std_logic := '0';
   signal data_in : std_logic_vector(15 downto 0) := (others => '0');

	--BiDirs
   signal fdata : std_logic_vector(15 downto 0);

 	--Outputs
   signal faddr : std_logic_vector(1 downto 0);
   signal slrd : std_logic;
   signal slwr : std_logic;
   signal sloe : std_logic;
   signal pktend : std_logic;
   signal clk_out : std_logic;
   signal data_out : std_logic_vector(15 downto 0);

   -- Clock period definitions
   constant clk_in_period : time := 21 ns;
   constant clk_out_period : time := 21 ns;
	
	-- Data generator
	signal counter: std_logic_vector(15 downto 0) := x"0000";

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
          clk_in => clk_in,
          clk_out => clk_out,
          button => button,
          send_req => send_req,
          data_out => data_out,
          data_in => data_in
        );

   -- Clock process definitions
   clk_in_process :process
   begin
		clk_in <= '0';
		wait for clk_in_period/2;
		clk_in <= '1';
		wait for clk_in_period/2;
   end process;

   clk_out_process :process
   begin
		clk_out <= '0';
		wait for clk_out_period/2;
		clk_out <= '1';
		wait for clk_out_period/2;
   end process;

	-- Start up reset
	button <= '0', '1' after 100 ns;

	-- flags signaling. All them are low_active
	flags_proc: process
	begin
		flaga <= '1'; -- ep2full
		flagb <= '0'; -- ep8empty
		flagc	<= '1'; -- ep8full
		flagd <= '0'; -- ep2empty
		wait until button = '1';
		
		wait until falling_edge(clk_in);

		flagb <= '1';
		wait until counter = x"0060";
		wait until falling_edge(clk_in);
		
		flagb <= '0';
		wait until pktend = '0';
	end process;
	
	-- Data counter
	data_proc: process(slrd)
	begin
		if button = '0' then
			counter <= x"0000";
		elsif rising_edge(slrd)then
			counter <= counter + 1;
		end if;
	end process;
	
   -- Stimulus process
	with flagb select
		fdata <= counter when '1',(others => 'Z')when others;
	
END;
