-- Internal Memory
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;

entity fi_ram_memory is
  generic
  (
    port_width: integer := 15;
    mem_depth:  integer := 9    -- en bits
  );
  port
  (
    address:  in    std_logic_vector((mem_depth-1) downto 0);
    data_in:  in    std_logic_vector(port_width downto 0);
    data_out: out   std_logic_vector(port_width downto 0);
    push:     in    std_logic;
    pop:      in    std_logic;
    reset:    in    std_logic

  );
end entity fi_ram_memory;

architecture beh of fi_ram_memory is

  signal  write_addr:       std_logic_vector((mem_depth-1) downto 0) := (others => '0');
  signal  read_addr:        std_logic_vector((mem_depth-1) downto 0);

  type memory is array ((mem_depth**2)-1 downto 0) of std_logic_vector(port_width downto 0);

  signal data_mem:  memory;
  begin

    read_addr <= address;
    data_out <= data_mem(conv_integer(read_addr));

    process(reset, push)
    begin
      if(reset  = '1')then
        write_addr <= (others => '0');
      elsif(rising_edge(push))then
        data_mem(conv_integer(write_addr)) <= data_in;
        write_addr <= write_addr + '1';
      end if;
    end process;

  end beh;
