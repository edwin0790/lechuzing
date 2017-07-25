--------------------------------------------------------------------------------
--Trabajo Final de Ingeniería Electrónica
--FX2LP - FPGA Interface
--Universidad Nacional de San Juan
--Autor: Edwin Barragan
--
--Asesores: 	Cristian Sisterna
--			Martín Perez
--			Marcelo Segura
--
--Año 2017
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
library unisim;
use unisim.vcomponents.all;

entity fx2lp_interface_top is
  generic(
  -- address are:|
  --  * EP8 = "11"
  constant in_ep_addr:	std_logic_vector(1 downto 0) := "00";
  constant out_ep_addr:	std_logic_vector(1 downto 0) := "11";
  constant port_width: integer := 15
  );
  port(
    -- señales que van y vienen desde y hacia el FX2LP
    fdata   : inout std_logic_vector(port_width downto 0);  -- entrada y salida de datos FIFO
    faddr   : out   std_logic_vector(1 downto 0);           -- canal FIFO
    slrd    : out   std_logic;                              -- señal de lectura
    slwr    : out   std_logic;                              -- señal de escritura

                                                            -- EP2 streaming in (to pc)
    flaga   : in    std_logic;                              -- EP2_full
    flagb   : in    std_logic;                              -- EP2_empty
                                                            -- EP8 bulk out (from pc)
    flagc   : in    std_logic;                              -- EP8_full
    flagd   : in    std_logic;                              -- EP8_empty
    sloe    : out   std_logic;                              -- señal de habilitación de salida

    pktend  : out   std_logic;
    done    : out   std_logic;
    -- reloj
      -- se utiliza el reloj que provee el EZ-USB-FX2LP
    clk_in  : in    std_logic;                              -- entrada de reloj
    clk_out : out   std_logic;                              -- salido de reloj

    -- señales que se comunican desde y hacia el sistema
    reset   : in    std_logic;                              -- fundamentalmente para sincronización
    send_req: in    std_logic;                              -- pedido de envío de datos
    data_out: out   std_logic_vector(port_width downto 0);
    data_in : in    std_logic_vector(port_width downto 0)
  );
end fx2lp_interface_top;

architecture fx2lp_interface_arq of fx2lp_interface_top is

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

  component fifo_512x8
  port(
    din:        in  std_logic_vector(15 downto 0);
    write_busy: in  std_logic;
    fifo_full:  out std_logic;
    dout:       out std_logic_vector(15 downto 0);
    read_busy:  in  std_logic;
    fifo_empty: out std_logic;
    fifo_clk:   in  std_logic;
    reset_al:   in  std_logic;
    fifo_flush: in  std_logic
 	);
  end component;

  signal sys_clk                                :   std_logic;
  signal pll_0, pll_90, pll_180, pll_270        :   std_logic;
  signal locked                                 :   std_logic;
  signal slwr_int, slrd_int, sloe_int, done_int :   std_logic;
  signal faddr_int                              :   std_logic_vector(1 downto 0);
  signal fdata_out, fdata_in                    :   std_logic_vector(port_width downto 0);
  signal read_empty_flag, read_full_flag        :   std_logic;
  signal write_empty_flag, write_full_flag      :   std_logic;
  signal write_req                              :   std_logic;

  signal fifo_flush                             :   std_logic;
  signal fifo_push, fifo_pop, fifo_full, fifo_empty : std_logic;

  -- Maquinas de Estados: xc6slx9-2tqg144
      --Maquina global
      type global_states is
      (
        idle,
        read_addr, read_wait_empty, read_read, read_end,
        write_addr, write_no_full, write_write, write_end
      );
      signal curr_state, next_state : global_states := idle;
begin

  oddr_y : ODDR2 	                                           -- clk out buffer
  port map
  (
   D0 	=> '1',
   D1 	=> '0',
   CE 	=> '1',
   C0	=> pll_180,
   C1	=> (not pll_180),
   R  	=> '0',
   S  	=> '0',
   Q  	=> clk_out
  );

  pll : clk_wiz_v3_6
  port map(
    CLK_IN1   => clk_in,
    CLK_OUT1  => pll_0,
    CLK_OUT2  => pll_90,
    CLK_OUT3  => pll_180,
    CLK_OUT4  => pll_270,
    RESET     => '0',
    LOCKED    => locked
  );

  fifo: fifo_512x8
  port map(
    din         => fdata_in,
    write_busy  => fifo_push,
    fifo_full   => fifo_full,
    dout        => fdata_out,
    read_busy   => fifo_pop,
    fifo_empty  => fifo_empty,
    fifo_clk    => sys_clk,
    reset_al    => reset,
    fifo_flush  => reset
  );

  -- reloj
  sys_clk <= pll_90;

  --conexiones de señales internas hacia el exterior
  slwr   <= slwr_int;
  slrd   <= slrd_int;
  sloe   <= sloe_int;
  faddr  <= faddr_int;
  pktend <= '1';
  -- done   <= done_int; --for debug

  write_full_flag  <= flaga;
  write_empty_flag  <= flagb;
  read_full_flag  <= flagc;
  read_empty_flag  <= flagd;

  write_req <= send_req;


  -- control signaling
  with curr_state select
    faddr_int <=  out_ep_addr when read_addr | read_wait_empty | read_read | read_end,
                  in_ep_addr  when write_addr | write_no_full | write_write | write_end,
                  (others => 'Z') when others;

  slwr_int <= '0' when curr_state = write_write else
              '1';

  slrd_int <= '0' when curr_state = read_read else
              '1';

  with curr_state select
    sloe_int <= '0' when read_wait_empty | read_read | read_end,
                '1' when others;

  fdata <= fdata_out when curr_state = write_write else (others => 'Z');

  fdata_in <= fdata when curr_state = read_read else (others => 'Z');
--              (others => '0');

-- control de la memoria
  fifo_push <= ((not slrd_int) and (not fifo_full));
  fifo_pop  <= ((not slwr_int) and ( fifo_empty));

  fifo_flush <= '1' when curr_state = read_addr else '0';

  -- Implementacion de las maquinas de estado
  fsm: process(curr_state, write_full_flag, read_empty_flag)
    begin
      case curr_state is
        when idle =>
          if(read_empty_flag = '1')then
            next_state <= read_addr;
          elsif((write_full_flag = '1') and (write_req = '1'))then
            next_state <= write_addr;
          else
            next_state <= idle;
          end if;

        when read_addr =>
          next_state <= read_wait_empty;

        when read_wait_empty =>
          if(read_empty_flag = '1')then
            next_state <= read_read;
          else
            next_state <= read_wait_empty;
          end if;

        when read_read =>
          next_state <= read_end;

        when read_end =>
          if(read_empty_flag = '1')then
            next_state <= read_read;
          else
            next_state <= idle;
          end if;

        when write_addr =>
          next_state <= write_no_full;

        when write_no_full =>
          if(read_empty_flag = '1')then
            next_state <= idle;
          elsif(write_full_flag = '1')then
            next_state <= write_write;
          else
            next_state <= write_no_full;
          end if;

        when write_write =>
          next_state <= write_end;

        when write_end =>
          if((write_full_flag = '1') and (read_empty_flag = '1'))then
            next_state <= write_write;
          else
            next_state <= idle;
          end if;

        when others =>
          next_state <= idle;
      end case;
    end process fsm;

    -- reloj
    global_fsm_clk: process (sys_clk, reset)
    begin
      if(reset = '1')then
        curr_state <= idle;
      elsif(rising_edge(sys_clk))then
        curr_state <= next_state;
      end if;
    end process global_fsm_clk;

end fx2lp_interface_arq;
