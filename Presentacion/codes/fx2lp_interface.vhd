----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    17:23:43 05/29/2019 
-- Design Name: 
-- Module Name:    fx2lp_interface - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity fx2lp_interface is
	generic(
		constant in_ep_addr:	std_logic_vector(1 downto 0) := "00";
		constant out_ep_addr:	std_logic_vector(1 downto 0) := "11";
		constant port_width: integer := 16
	);
	port(
		clk	: in	std_logic;										-- entrada de reloj
		reset	: in	std_logic;
	
		-- desde y hacia la interfaz
		fdata	: inout std_logic_vector(port_width-1 downto 0);  -- entrada y salida de datos FIFO
		faddr	: out	std_logic_vector(1 downto 0);           -- canal FIFO
		slrd	: out	std_logic;                              -- senal de lectura
		slwr	: out	std_logic;                              -- senal de escritura

																				-- EP2 streaming in (to pc)
		flaga	: in	std_logic;                              -- EP2_full--->write_full_flag
		flagb	: in	std_logic;                              -- EP8_empty-->read_empty_flag
																				-- EP8 bulk out (from pc)
		flagc	: in	std_logic;                              -- EP8_full--->read_full_flag
		flagd	: in	std_logic;                              -- EP2_empty-->write_empty_flag
		sloe	: out	std_logic;                              -- senal de habilitacion de salida

		pktend: out	std_logic;
		
		-- desde y hacia el sistema
		send_req	:in std_logic;                              -- pedido de envío de datos
		rx_data	:out std_logic_vector(port_width-1 downto 0);
		data_to_tx	:in std_logic_vector(port_width-1 downto 0)
	);
end fx2lp_interface;

architecture Behavioral of fx2lp_interface is

	signal slwr_int	: std_logic := '1';
	signal slrd_int	: std_logic := '1';
	signal sloe_int	: std_logic := '1';
	signal pktend_int	: std_logic := '1';
	signal faddr_int	: std_logic_vector(1 downto 0) := "ZZ";
	signal fdata_out	: std_logic_vector(port_width-1 downto 0);
	signal fdata_in	: std_logic_vector(port_width-1 downto 0);
	signal rd_eflag	: std_logic := '1';
	signal rd_fflag	: std_logic := '1';
	signal wr_eflag	: std_logic := '1';
	signal wr_fflag	: std_logic := '1';

	signal sys_clk		: std_logic;

	-- segnales de temporizacion
	signal count3													: natural range 0 to 4 := 0;
	signal count2													: natural range 0 to 3 := 0;
	signal trig3, trig2											: std_logic := '0';

	-- maquina de estados de la interfaz
	type if_fsm is
	(
		idle,
		read_addr, read_no_empty, read_read,
		write_addr, write_no_full, write_write, write_end
	);
	signal curr_state, next_state								: if_fsm := idle;

begin
	-- conexion de segnales internas hacia los puertos
	sys_clk <= clk;

	slwr   <= slwr_int;
	slrd   <= slrd_int;
	sloe   <= sloe_int;
	faddr  <= faddr_int;
	pktend <= pktend_int;

	wr_fflag  <= not flaga;
	rd_eflag  <= not flagb;

	rx_data <= fdata_in;
	fdata_out <= data_to_tx;
	
	-- segnalizacion
	with curr_state select
		faddr_int <=	out_ep_addr when read_addr | read_no_empty | read_read,-- | idle,--edwin,
							in_ep_addr  when write_addr | write_no_full | write_write | write_end,
							(others => 'Z') when others;

	slwr_int <=	'0' when next_state = write_write else
					'1';

	slrd_int <= '0' when curr_state = read_no_empty else
					'1';

	pktend_int <= ((not rd_eflag) or send_req);
				
	with curr_state select
		sloe_int <=	'0' when read_addr | read_read | read_no_empty,
						'1' when others;

	with curr_state select
					--dout->fdata_out
		fdata <=	fdata_out        when write_no_full | write_write | write_end | write_addr,
					(others => 'Z')  when others;

	with curr_state select
		fdata_in <=	fdata     when read_no_empty | read_read | read_addr,
						fdata_in  when others;
	
	--implementacion de la maquina de estados
	interfaz_fsm: process(curr_state, wr_fflag, rd_eflag, send_req)
	begin
		case curr_state is
			when idle =>
				if rd_eflag = '0' then
					next_state <= read_addr;
				elsif send_req = '1' then
					if wr_fflag = '0' then
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
				if rd_eflag = '0' then
					next_state <= read_addr;
				else
					next_state <= idle;
				end if;

			when write_addr =>
					next_state <= write_no_full;

			when write_no_full =>
				next_state <= write_write;

			when write_write =>
				next_state <= write_end;
								
			when write_end =>
				if send_req = '1' then
					if rd_eflag = '1' then
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

	global_fsm_clk: process (sys_clk, reset)
	begin
		if reset = '0' then
			curr_state <= idle;
		elsif rising_edge(sys_clk) then
			if count2 = 0 and count3 = 0 then
				curr_state <= next_state;
			end if;
		end if;
	end process global_fsm_clk;

end Behavioral;

