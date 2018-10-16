-- Internal Memory
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

entity fifo_ram is
	generic
	(
		port_width: integer := 16;
		mem_depth:  integer := 9    -- en bits
	);
	port
	(
		reset:	in	std_logic;
		push:	in	std_logic;
		pop:	in	std_logic;
		din:	in	std_logic_vector((port_width - 1) downto 0);
		dout:	out	std_logic_vector((port_width - 1) downto 0);
		full:	out	std_logic;
		empty:	out	std_logic
	);
end entity fifo_ram;

architecture beh of fifo_ram is

	signal  write_ptr:		std_logic_vector((mem_depth-1) downto 0) := (others => '0');
	signal  read_ptr:		std_logic_vector((mem_depth-1) downto 0) := (others => '0');
	signal	write_quant:	std_logic_vector(mem_depth downto 0) := (others => '0');
	signal	read_quant:		std_logic_vector(mem_depth downto 0) := (others => '0');
	signal  data_quant:		std_logic_vector(mem_depth downto 0);
	signal	s_full:			std_logic;
	signal	s_empty:		std_logic;
	signal	neg_cero:		std_logic_vector(mem_depth downto 0);
	signal	pos_cero:		std_logic_vector(mem_depth downto 0) := (others => '0');

	type memory is array ((mem_depth**2)-1 downto 0) of std_logic_vector(port_width-1 downto 0);

	signal data_mem:  memory;
	begin

	data_mem(conv_integer(write_ptr)) <= din;
	dout <= data_mem(conv_integer(read_ptr));

	full <= s_full;
	empty <= s_empty;
	
	data_quant <= write_quant - read_quant;
	
	-- La profundidad de la memoria es de X bytes. Para ello, debemos poder barrer todos los X bytes.
	-- entonces es necesario un contador con X+1 Bytes. Esto exige un bit más. Cuando este bit se
	-- enciende, debe marcar overflow y mostrar un cero.
	overflow_mark: for i in mem_depth downto 0 generate
		if_minus: if i < mem_depth generate
			neg_cero(i) <= '0';
		end generate if_minus;
		if_top: if i = mem_depth generate
			neg_cero(i) <= '1';
		end generate if_top;
	end generate overflow_mark;

	process(reset, pop)
	begin
		if(reset = '1')then
			read_ptr <= (others => '0');
			read_quant <= (others => '0');
		elsif(rising_edge(pop) and (s_empty = '0'))then
			read_ptr <= (read_ptr + '1');
			read_quant <= read_quant + '1';
		end if;
	
	end process;
	
	process(reset, push)
	begin
		if(reset = '1')then
			write_ptr <= (others => '0');
			write_quant <= (others => '0');
		elsif(rising_edge(push) and (s_full = '0'))then
			write_ptr <= (write_ptr + '1');
			write_quant <= write_quant + '1';
		end if;
	end process;
	
	process(data_quant)
	begin
		if(data_quant = pos_cero)then
			s_empty <= '1';
			s_full <= '0';
		elsif(data_quant = neg_cero - 1)then -- me está robando un byte, le vamos a poner un byte extra..
			s_full <= '1';
			s_empty <= '0';
		else
			s_full <= '0';
			s_empty <= '0';
		end if;
	end process;
	
	end beh;
