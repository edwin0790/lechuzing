--------------------------------------------------------------------------------
-- Company: 
-- Engineer:
--
-- Create Date:   09:20:43 01/09/2018
-- Design Name:   
-- Module Name:   /home/lechuzin/Facultad/Trabajo Final/lechuzing/Cyclon6/fifo_tb.vhd
-- Project Name:  Cyclon6
-- Target Device:  
-- Tool versions:  
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: fifo_ram
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
 
ENTITY fifo_tb IS
END fifo_tb;
 
ARCHITECTURE behavior OF fifo_tb IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
 
    COMPONENT fifo_ram
	generic(
		port_width: integer:=16;
		mem_depth:	integer:=9);
    PORT(
         reset : IN  std_logic;
         push : IN  std_logic;
         pop : IN  std_logic;
         din : IN  std_logic_vector(15 downto 0);
         dout : OUT  std_logic_vector(15 downto 0);
         full : OUT  std_logic;
         empty : OUT  std_logic
        );
    END COMPONENT;
    

   --Inputs
   signal reset : std_logic := '0';
   signal push : std_logic := '0';
   signal pop : std_logic := '0';
   signal din : std_logic_vector(15 downto 0) := (others => '0');

 	--Outputs
   signal dout : std_logic_vector(15 downto 0);
   signal full : std_logic;
   signal empty : std_logic;
   -- No clocks detected in port list. Replace <clock> below with 
   -- appropriate port name
   signal reloj	:	std_logic := '0';
   signal mem_depth: integer := 2;
 
   constant reloj_period : time := 10 ns;
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: fifo_ram generic map(
		  mem_depth => mem_depth)
		PORT MAP (
          reset => reset,
          push => push,
          pop => pop,
          din => din,
          dout => dout,
          full => full,
          empty => empty
        );

   -- Clock process definitions
   reloj_process :process
   begin
		reloj <= '0';
		wait for reloj_period/2;
		reloj <= '1';
		wait for reloj_period/2;
   end process;
 

   -- Stimulus process
   stim_proc: process
   begin		
      -- hold reset state for 100 ns.
	  reset <= '1';
      wait for 100 ns;	
	  
	  reset <= '0';
	  din <= x"26AD";
	  push <= '1';
      wait for reloj_period*3;
	  push <= '0';
	  
	  din <= x"ABC4";
	  
	  wait for reloj_period;
	  push <= '1';
	  wait for reloj_period;
	  push <= '0';
	  din <= x"3333";
	  wait for reloj_period;
	  push <= '1';
	  wait for reloj_period;
	  push <= '0';
	  din <= x"FFFF";
	  
	  wait for reloj_period;
	  push <= '1';
	  wait for reloj_period;
	  push <= '0';
	  
	  pop <= '1';
	  wait for reloj_period;
	  pop <= '0';
	  
      -- insert stimulus here 

      wait;
   end process;

END;
