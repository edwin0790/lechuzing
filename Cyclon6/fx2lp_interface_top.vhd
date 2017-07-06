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
use ieee.numeric_std.all;

entity fx2lp_interface_top is
  generic(
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

    flaga   : in    std_logic;                              -- flags defindo por...leer en el firmware
    flagb   : in    std_logic;
    flagc   : in    std_logic;
    flagd   : in    std_logic;
    sloe    : out   std_logic;                              -- señal de habilitación de salida

    pktend  : out   std_logic;
    done    : out   std_logic;
    -- reloj
      -- se desconoce si se utiliza un reloj externo al de la placa ya que
      -- podría usarse el reloj global usado para mover el sistema que se pretende
      -- comunicar, uno interno generado por esta interfaz, o el reloj propio del
      -- FX2LP, por lo que se provee entrada y salida de reloj y un pin de
      -- seleccion, clk_src.
      -- En caso de reloj interno, el reloj externo será el de la Mojo, es decir
      -- de 50 MHz, para que el pll pueda obtener uina señal de 48 MHz
      -- clk_src '1' => reloj interno se emite por clk_out.
      -- clk_src '0' => timing dado por reloj externo
    clk_in  : in    std_logic;                              -- entrada de reloj
    clk_out : out   std_logic;                              -- salido de reloj
    clk_src : in    std_logic;                              -- seleccion de modo de reloj.

    -- señales que se comunican desde y hacia el sistema
    reset   : in    std_logic                               -- fundamentalmente para sincronización
  );
end fx2lp_interface_top;

architecture fx2lp_interface_arq of fx2lp_interface_top is
  component clk_wiz_v3_6
  port(
    CLK_IN1           : in     std_logic;
    CLK_OUT1          : out    std_logic;
    CLK_OUT2          : out    std_logic;
    CLK_OUT3          : out    std_logic;
    CLK_OUT4          : out    std_logic;
    RESET             : in     std_logic;
    LOCKED            : out    std_logic
   );
 end component;

  signal sys_clk                                :   std_logic;
  signal pll_0, pll_90, pll_180, pll_270        :   std_logic;
  signal locked                                 :   std_logic;
  signal slwr_int, slrd_int, sloe_int, done_int :   std_logic;
  signal faddr_int                              :   std_logic_vector(1 downto 0);
  signal fdata_out, fdata_in                    :   std_logic_vector(port_width downto 0);

  -- Maquinas de Estados:
    --Por simplicidad, se plantean tres MAE's: una general que define si hacemos
    -- una lectura, una escritura, o estamos a la espera de una evento.
    --Cuando este evento ocurre, se dispara una de las otras dos MAE's, ya sea,
    -- para leer o escribir datos.
      --Maquina de lectura
      type read_states is (read_idle, read_addr, read_wait_empty, read_read, read_end);
      signal curr_read_state, next_read_state : read_states;
      --Maquina de escritura
      type write_states is (write_idle, write_addr, write_no_full, write_write, write_end);
      signal curr_write_state, nex_write_state : write_states;
      --Maquina global
      type global_states is (idle, reading, writing);
      signal global_state : global_states := idle;
begin

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

  --selección de reloj
  sys_clk <=  clk_in  when clk_src = '0' else
              pll_180;

  clk_out <=  clk_in  when  clk_src = '0' else
              pll_0;

  --conexiones de señales internas hacia el exterior
  slwr        <= slwr_int;
  slrd        <= slrd_int;
  sloe        <= sloe_int;
  faddr       <= faddr_int;
  fdata       <= fdata_out;
  pktend      <= '1';
  done        <= done_int;

  -- control signaling
  faddr_int <=  out_ep_addr  when global_state = reading else
                in_ep_addr;

  slwr_int <= '0' when curr_write_state = write_write else
              '1';

  slrd_int <= '0' when curr_read_state = read_read else
              '1';

  sloe_int <= '0' when global_state = reading else
              '1';

  -- Implementacion de las maquinas de estado
end fx2lp_interface_arq;
