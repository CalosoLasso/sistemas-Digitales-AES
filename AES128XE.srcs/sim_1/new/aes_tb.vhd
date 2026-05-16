library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- ==========================================
-- ENTIDAD: Testbench General (Sin puertos)
-- ==========================================
entity aes_tb is
end aes_tb;

architecture behavior of aes_tb is

    -- 1. Declaración del Componente Principal (Top-Level)
    component micro_top
        Port (
            clk      : in  STD_LOGIC;
            rst      : in  STD_LOGIC;
            start    : in  STD_LOGIC;
            enc_dec  : in  STD_LOGIC;
            key_in   : in  STD_LOGIC_VECTOR(127 downto 0);
            data_out : out STD_LOGIC_VECTOR(127 downto 0);
            done     : out STD_LOGIC
        );
    end component;

    -- 2. Señales internas del Testbench
    signal clk      : STD_LOGIC := '0';
    signal rst      : STD_LOGIC := '1'; -- Iniciamos con Reset en alto
    signal start    : STD_LOGIC := '0';
    signal enc_dec  : STD_LOGIC := '0';
    signal key_in   : STD_LOGIC_VECTOR(127 downto 0) := (others => '0');
    signal data_out : STD_LOGIC_VECTOR(127 downto 0);
    signal done     : STD_LOGIC;

    -- Configuración del reloj (100 MHz)
    constant clk_period : time := 10 ns;

begin

    -- ==========================================
    -- INSTANCIACIÓN DEL SISTEMA COMPLETO (UUT)
    -- ==========================================
    uut: micro_top PORT MAP (
        clk      => clk,
        rst      => rst,
        start    => start,
        enc_dec  => enc_dec,
        key_in   => key_in,
        data_out => data_out,
        done     => done
    );

    -- ==========================================
    -- GENERADOR DE RELOJ
    -- ==========================================
    clk_process :process
    begin
        clk <= '0';
        wait for clk_period/2;
        clk <= '1';
        wait for clk_period/2;
    end process;

    -- ==========================================
    -- PROCESO DE ESTÍMULOS PRINCIPAL
    -- ==========================================
    stim_proc: process
    begin
        -- 1. Mantener Reset activo unos ciclos
        rst <= '1';
        start <= '0';
        wait for 30 ns;
        
        -- 2. Quitar Reset y configurar la operación
        rst <= '0';
        enc_dec <= '1'; -- '1' = Encriptar
        
        -- Inyectamos una llave de ejemplo (La que usará key_expansion)
        key_in <= x"2b7e151628aed2a6abf7158809cf4f3c"; 
        wait for clk_period * 2;

        -- 3. Dar el pulso de START para iniciar la máquina de estados
        start <= '1';
        wait for clk_period;
        start <= '0'; -- Bajamos el start, la FSM debe continuar sola

        -- 4. Esperar a que el microcontrolador termine (done = '1')
        -- Ponemos un timeout de seguridad por si la FSM se queda trabada
        wait until (done = '1') for 1000 ns; 
        
        -- Mantenemos la simulación corriendo un poco más para ver el resultado final
        wait for 50 ns;

        -- Detener la simulación
        wait;
    end process;

end behavior;