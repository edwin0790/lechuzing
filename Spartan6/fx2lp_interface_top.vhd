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
use ieee.numeric_std.all;
library unisim;
use unisim.vcomponents.all;

entity fx2lp_interface_top is
  generic(
  -- addresses are:|
  --  * EP8 = "11"
  --  * EP2 = "00"
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
    flaga   : in    std_logic;                              -- EP2_full--->write_full_flag
    flagb   : in    std_logic;                              -- EP8_empty-->read_empty_flag
                                                            -- EP8 bulk out (from pc)
    flagc   : in    std_logic;                              -- EP8_full--->read_full_flag
    flagd   : in    std_logic;                              -- EP2_empty-->write_empty_flag
    sloe    : out   std_logic;                              -- señal de habilitación de salida

    pktend  : out   std_logic;
    done    : out   std_logic;
    -- reloj
      -- se utiliza el reloj que provee el EZ-USB-FX2LP
    clk_in  : in    std_logic;                              -- entrada de reloj
    clk_out : out   std_logic;                              -- salido de reloj

    -- señales que se comunican desde y hacia el sistema
    reset   : in    std_logic;                              -- fundamentalmente para sincronización..activo en bajo
    send_req: in    std_logic;                              -- pedido de envío de datos
    data_out: out   std_logic_vector(port_width downto 0);
    data_in : in    std_logic_vector(port_width downto 0);
	
	led		: out	std_logic_vector(7 downto 0)
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

  component fifo_ram
  generic(
	port_width: integer;
	mem_depth:	integer
  );
  port(
	reset:	in	std_logic;
	push:	in	std_logic;
	pop:	in	std_logic;
	din:	in	std_logic_vector;
	dout:	out	std_logic_vector;
	full:	out	std_logic;
	empty:	out	std_logic
  );
  end component;

  signal sys_clk                                :   std_logic;
  signal pll_0, pll_90, pll_180, pll_270        :   std_logic;
  signal locked                                 :   std_logic;
  signal slwr_int, slrd_int, sloe_int, done_int :   std_logic;
  signal pktend_int								:	std_logic;
  signal push_int, pop_int						:	std_logic;
  signal faddr_int                              :   std_logic_vector(1 downto 0);
  signal fdata_out, fdata_in                    :   std_logic_vector(port_width downto 0);
  signal read_empty_flag, read_full_flag        :   std_logic;
  signal write_empty_flag, write_full_flag      :   std_logic;
  signal write_req                              :   std_logic;

  signal fifo_flush                             :   std_logic;
  signal fifo_push, fifo_pop, fifo_full, fifo_empty : std_logic;
  
  signal debug_clk : std_logic := '0';
  signal count3:	natural range 0 to 3 := 0;
  signal count2:	natural range 0 to 2 := 0;
  signal cont: natural range 0 to 16777215 := 10000000;
  
  signal trig3, trig2 : std_logic := '0';
--  signal tg_a_3, tg_b_3, tg_a_2, tg_b_2: std_logic := '0';
  
--  signal clk_in1, clk_in2 : std_logic;

  -- Maquinas de Estados: xc6slx9-2tqg144
      --Maquina global
      type global_states is
      (
        idle,
        read_addr, read_no_empty, read_read,
        write_addr, write_no_full, write_write, write_end
      );
      signal curr_state, next_state : global_states := idle;
	  signal num_state : std_logic_vector(3 downto 0);
begin
	
	with curr_state select
		num_state <= 	"1111" when idle,
						"0101" when read_addr,
						"0110" when read_no_empty,
						"0111" when read_read,
						"0001" when write_addr,
						"0010" when write_no_full,
						"0011" when write_write,
						"0000" when write_end;
	--debuggin leds
	led(0) <= fifo_empty;
	led(7) <= '1' when fdata_out = x"35" else '0';
	led(6) <= write_empty_flag;
	led(5) <= write_full_flag;
	led(4) <= read_empty_flag;
--	led(3 downto 0) <= std_logic_vector(to_unsigned(count2, 4));
	led(2 downto 1) <= faddr_int;
	led(3) <= debug_clk;
--	led(7 downto 4) <= num_state;
	
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

  fifo: fifo_ram
  generic map(
	mem_depth	=> 9,
--	mem_depth	=> 2,
	port_width	=> 16
  )
  port map(
	reset		=> not reset, --reset de la memoria activo en alto
	push		=> fifo_push,
	pop			=> fifo_pop,
	din			=> fdata_in,
	dout		=> fdata_out,
	full		=> fifo_full,
	empty		=> fifo_empty
	
--    din         => fdata_in,
--    write_busy  => fifo_push,
--    fifo_full   => fifo_full,
--    dout        => fdata_out,
--    read_busy   => fifo_pop,
--    fifo_empty  => fifo_empty,
--    fifo_clk    => sys_clk,
--    reset_al    => reset,
--    fifo_flush  => fifo_flush
  );

  -- reloj
  sys_clk <= pll_90;

  --conexiones de señales internas hacia el exterior
  slwr   <= slwr_int;
  slrd   <= slrd_int;
  sloe   <= sloe_int;
  faddr  <= faddr_int;
  pktend <= pktend_int;
  -- done   <= done_int; --for debug

  write_full_flag  <= flaga;
  write_empty_flag  <= flagd;
  read_full_flag  <= flagc;
  read_empty_flag  <= flagb;

  write_req <= not fifo_empty;


  -- control signaling
  with curr_state select
    faddr_int <=  out_ep_addr when read_addr | read_no_empty | read_read,
                  in_ep_addr  when write_addr | write_no_full | write_write | write_end,
                  (others => 'Z') when others;

  slwr_int <= '0' when next_state = write_write else
              '1';

  slrd_int <= '0' when curr_state = read_no_empty else
              '1';

  pop_int <= '0' when (curr_state = write_end) else
              '1';

  push_int <=	'0' when curr_state = read_read else
				'1';
  
--  pktend_int <= '0' when curr_state = write_write and next_state = idle else
--				'1';
				
  with curr_state select
    sloe_int <= '0' when read_read | read_no_empty,
                '1' when others;

  with curr_state select
    fdata <=  fdata_out        when write_no_full | write_write | write_end,
              (others => 'Z')  when others;

  with curr_state select
    fdata_in <= fdata     when read_no_empty | read_read,
                fdata_in  when others;
--              (others => '0');

	trig3 <= '1' when (next_state = write_write) else '0';

	with next_state select
	trig2 <= 	'1' when read_no_empty | read_read | write_no_full | write_end,
				'0' when others;
				
	pktend_int <= not fifo_empty;
				 --'1' when fifo_empty = '0' else '0';	
											--or curr_state /= idle else '0';
					
-- control de la memoria
  fifo_push <= ((not push_int) and (not fifo_full));
  fifo_pop  <= ((not pop_int) and (not fifo_empty));

--memoria vieja
  fifo_flush <= '1' when reset = '0' else '0';

  -- Implementacion de las maquinas de estado
  fsm: process(curr_state, write_full_flag, read_empty_flag, write_req)
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
          if(read_empty_flag = '1')then
			next_state <= read_no_empty;
          else
            next_state <= read_addr;
          end if;

        when read_no_empty =>
          next_state <= read_read;

        when read_read =>
          if(read_empty_flag = '1')then
            next_state <= read_no_empty;
          else
            next_state <= idle;
          end if;

        when write_addr =>
           if(read_empty_flag = '1')then
            next_state <= idle;
          elsif(write_full_flag = '1')then
            next_state <= write_no_full;
          else
            next_state <= write_addr;
          end if;

        when write_no_full =>
          next_state <= write_write;

        when write_write =>
          if((write_full_flag = '1') and (read_empty_flag = '0') and (write_req = '1'))then
            next_state <= write_end;
          else
            next_state <= idle;
          end if;
		  
		when write_end =>
          if(write_req = '1')then
            next_state <= write_write;
          else
            next_state <= idle;
          end if;
 
        when others =>
          next_state <= idle;
      end case;
    end process fsm;
	
	counter3: process(sys_clk, reset, trig3)
	begin
		if reset = '0' then
			count3 <= 0;
		elsif rising_edge(sys_clk) then
			if count3 > 0 then
				count3 <= count3 - 1;
			elsif trig3 = '1' then
				count3 <= 3;
			end if;
		end if;
	end process counter3;
	
	counter2: process(sys_clk, reset, trig2)
	begin
		if reset = '0' then
			count2 <= 0;
		elsif rising_edge(sys_clk)then
			if count2 > 0 then
				count2 <= count2 - 1;
			elsif trig2 = '1' then
				count2 <= 2;
			end if;
		end if;
	end process counter2;
		
    -- reloj
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
	
	reloj_lento: process(pll_0)
	begin
		if(rising_edge(pll_0))then
			cont <= cont - 1;
			if cont = 0 then
				cont <= 10000000;
				debug_clk <= not debug_clk;
			end if;
		end if;
	end process reloj_lento;


end fx2lp_interface_arq;
