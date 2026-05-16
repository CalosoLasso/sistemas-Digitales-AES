library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- ==========================================
-- ENTIDAD: Generador de Claves y Memoria RAM
-- ==========================================
entity key_expansion is
    Port (
        clk        : in  STD_LOGIC;
        rst        : in  STD_LOGIC;
        load_key   : in  STD_LOGIC;                      -- '1' = Inicia el pre-cálculo de todas las claves
        key_in     : in  STD_LOGIC_VECTOR(127 downto 0); -- Clave secreta original del usuario
        round_num  : in  STD_LOGIC_VECTOR(3 downto 0);   -- Dirección de lectura (Qué clave queremos usar ahora)
        
        ready      : out STD_LOGIC;                      -- '1' = Ya terminó de calcular las 11 claves
        round_key  : out STD_LOGIC_VECTOR(127 downto 0)  -- Clave entregada al Datapath
    );
end key_expansion;

-- ==========================================
-- ARQUITECTURA
-- ==========================================
architecture Behavioral of key_expansion is

    -- 1. Componente S-Box (Necesitamos 4 para la función SubWord)
    component sbox
        Port (
            byte_in  : in  STD_LOGIC_VECTOR (7 downto 0);
            byte_out : out STD_LOGIC_VECTOR (7 downto 0)
        );
    end component;

    -- 2. Memoria RAM interna (Lista de 11 espacios de 128 bits)
    type key_array is array (0 to 10) of STD_LOGIC_VECTOR(127 downto 0);
    signal key_mem : key_array;

    -- 3. Señales de control interno
    signal calc_round  : integer range 0 to 10 := 0; -- Contador interno para calcular
    signal calculating : STD_LOGIC := '0';           -- Bandera de estado
    signal sig_ready   : STD_LOGIC := '0';

    -- 4. Señales combinacionales para la matemática de la clave
    signal prev_key    : STD_LOGIC_VECTOR(127 downto 0);
    signal w3          : STD_LOGIC_VECTOR(31 downto 0);
    signal rot_w3      : STD_LOGIC_VECTOR(31 downto 0);
    signal sub_w3      : STD_LOGIC_VECTOR(31 downto 0);
    signal rcon        : STD_LOGIC_VECTOR(31 downto 0);
    
    signal next_w0, next_w1, next_w2, next_w3 : STD_LOGIC_VECTOR(31 downto 0);
    signal next_key    : STD_LOGIC_VECTOR(127 downto 0);

    -- 5. Tabla de Constantes de Ronda (Rcon)
    function get_rcon(round : integer) return STD_LOGIC_VECTOR is
    begin
        case round is
            when 1  => return x"01000000";
            when 2  => return x"02000000";
            when 3  => return x"04000000";
            when 4  => return x"08000000";
            when 5  => return x"10000000";
            when 6  => return x"20000000";
            when 7  => return x"40000000";
            when 8  => return x"80000000";
            when 9  => return x"1B000000";
            when 10 => return x"36000000";
            when others => return x"00000000";
        end case;
    end function;

begin

    -- =========================================================
    -- A. MATEMÁTICA COMBINACIONAL DEL KEY EXPANSION
    -- =========================================================
    -- Tomamos la clave anterior directamente de la memoria según por dónde vayamos
    prev_key <= key_mem(calc_round - 1) when calc_round > 0 else (others => '0');
    
    -- Extraemos la última palabra de 32 bits (w3)
    w3 <= prev_key(31 downto 0);

    -- RotWord: Desplazamiento circular de un byte
    rot_w3 <= w3(23 downto 0) & w3(31 downto 24);

    -- SubWord: Instanciamos las 4 S-Boxes
    SBOX_0: sbox port map (byte_in => rot_w3(31 downto 24), byte_out => sub_w3(31 downto 24));
    SBOX_1: sbox port map (byte_in => rot_w3(23 downto 16), byte_out => sub_w3(23 downto 16));
    SBOX_2: sbox port map (byte_in => rot_w3(15 downto 8),  byte_out => sub_w3(15 downto 8));
    SBOX_3: sbox port map (byte_in => rot_w3(7 downto 0),   byte_out => sub_w3(7 downto 0));

    -- Obtenemos el Rcon de la ronda actual
    rcon <= get_rcon(calc_round);

    -- Calculamos las 4 nuevas palabras (w0, w1, w2, w3) mediante XORs encadenados
    next_w0 <= prev_key(127 downto 96) xor sub_w3 xor rcon;
    next_w1 <= prev_key(95 downto 64)  xor next_w0;
    next_w2 <= prev_key(63 downto 32)  xor next_w1;
    next_w3 <= prev_key(31 downto 0)   xor next_w2;

    -- Unimos las 4 palabras en la nueva clave de 128 bits
    next_key <= next_w0 & next_w1 & next_w2 & next_w3;

    -- =========================================================
    -- B. PROCESO SÍNCRONO: LLENADO DE LA MEMORIA
    -- =========================================================
    process(clk, rst)
    begin
        if rst = '1' then
            calc_round  <= 0;
            calculating <= '0';
            sig_ready   <= '0';
            -- Limpiamos la memoria
            for i in 0 to 10 loop
                key_mem(i) <= (others => '0');
            end loop;
            
        elsif rising_edge(clk) then
            if load_key = '1' and calculating = '0' then
                -- INICIO: Guardamos la clave original en el espacio 0 y empezamos a calcular
                key_mem(0)  <= key_in;
                calc_round  <= 1;
                calculating <= '1';
                sig_ready   <= '0';
                
            elsif calculating = '1' then
                -- RUTINA DE LLENADO: En cada ciclo de reloj guardamos una clave calculada
                key_mem(calc_round) <= next_key;
                
                if calc_round = 10 then
                    -- Hemos terminado de calcular todas las claves
                    calculating <= '0';
                    sig_ready   <= '1'; -- ¡Avisamos a la Máquina de Estados que ya puede trabajar!
                else
                    -- Pasamos a la siguiente ronda
                    calc_round <= calc_round + 1;
                end if;
            end if;
        end if;
    end process;

    -- =========================================================
    -- C. LECTURA ASÍNCRONA (Para el Datapath)
    -- =========================================================
    -- Esto es como un multiplexor gigante: la FSM manda un número del 0 al 10 en "round_num"
    -- y este bloque le entrega instantáneamente la clave guardada en esa posición.
    
    round_key <= key_mem(to_integer(unsigned(round_num)));
    ready     <= sig_ready;

end Behavioral;