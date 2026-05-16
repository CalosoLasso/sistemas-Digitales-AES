library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- ==========================================
-- ENTIDAD: Camino de Datos (Dual: Enc y Dec)
-- ==========================================
entity aes_datapath is
    Port (
        clk         : in  STD_LOGIC;
        load_init   : in  STD_LOGIC; -- '1' = Carga Ronda inicial
        enc_dec     : in  STD_LOGIC; -- '1' = Encriptar, '0' = Desencriptar
        ctrl_mux    : in  STD_LOGIC; -- '1' = Salta MixColumns (Última ronda)
        data_in     : in  STD_LOGIC_VECTOR(127 downto 0); 
        round_key   : in  STD_LOGIC_VECTOR(127 downto 0); 
        data_out    : out STD_LOGIC_VECTOR(127 downto 0)  
    );
end aes_datapath;

-- ==========================================
-- ARQUITECTURA
-- ==========================================
architecture Behavioral of aes_datapath is

    -- 1. COMPONENTES: Las dos tablas de sustitución
    component sbox
        Port ( byte_in : in STD_LOGIC_VECTOR (7 downto 0); byte_out : out STD_LOGIC_VECTOR (7 downto 0) );
    end component;

    component inv_sbox
        Port ( byte_in : in STD_LOGIC_VECTOR (7 downto 0); byte_out : out STD_LOGIC_VECTOR (7 downto 0) );
    end component;

    -- Tipos de datos
    type state_array is array (0 to 15) of STD_LOGIC_VECTOR(7 downto 0);
    
    -- Señales de estado
    signal current_state : STD_LOGIC_VECTOR(127 downto 0);
    signal next_state    : STD_LOGIC_VECTOR(127 downto 0);
    signal state_arr     : state_array;
    
    -- Señales de Encriptación
    signal sb_out_arr, sr_out_arr, mc_out_arr : state_array;
    signal enc_mux_out : STD_LOGIC_VECTOR(127 downto 0);
    signal enc_next    : STD_LOGIC_VECTOR(127 downto 0);

    -- Señales de Desencriptación
    signal isr_out_arr, isb_out_arr, imc_out_arr : state_array;
    signal add_key_dec : STD_LOGIC_VECTOR(127 downto 0);
    signal dec_mux_out : STD_LOGIC_VECTOR(127 downto 0);
    signal dec_next    : STD_LOGIC_VECTOR(127 downto 0);

    -- 2. FUNCIONES MATEMÁTICAS (Galois Field)
    function xtime(b : STD_LOGIC_VECTOR(7 downto 0)) return STD_LOGIC_VECTOR is
    begin
        if b(7) = '1' then return (b(6 downto 0) & '0') xor x"1B";
        else return (b(6 downto 0) & '0'); end if;
    end function;

    -- Funciones para InvMixColumns (x9, x11, x13, x14)
    function mul_9(b : STD_LOGIC_VECTOR(7 downto 0)) return STD_LOGIC_VECTOR is
    begin return xtime(xtime(xtime(b))) xor b; end function;

    function mul_b(b : STD_LOGIC_VECTOR(7 downto 0)) return STD_LOGIC_VECTOR is
    begin return xtime(xtime(xtime(b)) xor b) xor b; end function;

    function mul_d(b : STD_LOGIC_VECTOR(7 downto 0)) return STD_LOGIC_VECTOR is
    begin return xtime(xtime(xtime(b) xor b)) xor b; end function;

    function mul_e(b : STD_LOGIC_VECTOR(7 downto 0)) return STD_LOGIC_VECTOR is
    begin return xtime(xtime(xtime(b) xor b) xor b); end function;

begin

    -- Convertir vector de 128 bits a arreglo de 16 bytes
    Gen_Map_In: for i in 0 to 15 generate
        state_arr(i) <= current_state(127 - (i*8) downto 120 - (i*8));
    end generate;

    -- =========================================================
    -- RUTA A: ENCRIPTACIÓN (enc_dec = '1')
    -- =========================================================
    
    -- A1. SubBytes
    Gen_SubBytes: for i in 0 to 15 generate
        SBOX_INST: sbox Port map (byte_in => state_arr(i), byte_out => sb_out_arr(i));
    end generate;

    -- A2. ShiftRows
    sr_out_arr(0) <= sb_out_arr(0); sr_out_arr(4) <= sb_out_arr(4); sr_out_arr(8) <= sb_out_arr(8); sr_out_arr(12) <= sb_out_arr(12);
    sr_out_arr(1) <= sb_out_arr(5); sr_out_arr(5) <= sb_out_arr(9); sr_out_arr(9) <= sb_out_arr(13); sr_out_arr(13) <= sb_out_arr(1);
    sr_out_arr(2) <= sb_out_arr(10); sr_out_arr(6) <= sb_out_arr(14); sr_out_arr(10) <= sb_out_arr(2); sr_out_arr(14) <= sb_out_arr(6);
    sr_out_arr(3) <= sb_out_arr(15); sr_out_arr(7) <= sb_out_arr(3); sr_out_arr(11) <= sb_out_arr(7); sr_out_arr(15) <= sb_out_arr(11);

    -- A3. MixColumns
    Gen_MixCol: for c in 0 to 3 generate
        mc_out_arr(c*4+0) <= xtime(sr_out_arr(c*4+0)) xor (xtime(sr_out_arr(c*4+1)) xor sr_out_arr(c*4+1)) xor sr_out_arr(c*4+2) xor sr_out_arr(c*4+3);
        mc_out_arr(c*4+1) <= sr_out_arr(c*4+0) xor xtime(sr_out_arr(c*4+1)) xor (xtime(sr_out_arr(c*4+2)) xor sr_out_arr(c*4+2)) xor sr_out_arr(c*4+3);
        mc_out_arr(c*4+2) <= sr_out_arr(c*4+0) xor sr_out_arr(c*4+1) xor xtime(sr_out_arr(c*4+2)) xor (xtime(sr_out_arr(c*4+3)) xor sr_out_arr(c*4+3));
        mc_out_arr(c*4+3) <= (xtime(sr_out_arr(c*4+0)) xor sr_out_arr(c*4+0)) xor sr_out_arr(c*4+1) xor sr_out_arr(c*4+2) xor xtime(sr_out_arr(c*4+3));
    end generate;

    -- A4. Mux de Encriptación (Salta MixCol en Ronda 10)
    Gen_Enc_Mux: for i in 0 to 15 generate
        enc_mux_out(127 - (i*8) downto 120 - (i*8)) <= sr_out_arr(i) when ctrl_mux = '1' else mc_out_arr(i);
    end generate;

    -- A5. AddRoundKey (Encriptación)
    enc_next <= enc_mux_out xor round_key;


    -- =========================================================
    -- RUTA B: DESENCRIPTACIÓN (enc_dec = '0')
    -- =========================================================
    
    -- B1. InvShiftRows (Desplaza hacia la derecha)
    isr_out_arr(0) <= state_arr(0); isr_out_arr(4) <= state_arr(4); isr_out_arr(8) <= state_arr(8); isr_out_arr(12) <= state_arr(12);
    isr_out_arr(1) <= state_arr(13); isr_out_arr(5) <= state_arr(1); isr_out_arr(9) <= state_arr(5); isr_out_arr(13) <= state_arr(9);
    isr_out_arr(2) <= state_arr(10); isr_out_arr(6) <= state_arr(14); isr_out_arr(10) <= state_arr(2); isr_out_arr(14) <= state_arr(6);
    isr_out_arr(3) <= state_arr(7); isr_out_arr(7) <= state_arr(11); isr_out_arr(11) <= state_arr(15); isr_out_arr(15) <= state_arr(3);

    -- B2. InvSubBytes (¡AQUÍ SE USA EL COMPONENTE QUE MENCIONASTE!)
    Gen_InvSubBytes: for i in 0 to 15 generate
        ISBOX_INST: inv_sbox Port map (byte_in => isr_out_arr(i), byte_out => isb_out_arr(i));
    end generate;

    -- Convertimos a vector para hacer AddRoundKey antes de InvMixColumns
    Gen_Dec_Vec: for i in 0 to 15 generate
        add_key_dec(127 - (i*8) downto 120 - (i*8)) <= isb_out_arr(i);
    end generate;
    
    -- B3. AddRoundKey (Desencriptación)
    dec_mux_out <= add_key_dec xor round_key;

    -- B4. InvMixColumns (Se aplica a dec_mux_out y se convierte de nuevo a arreglo)
    Gen_InvMixCol: for c in 0 to 3 generate
        imc_out_arr(c*4+0) <= mul_e(dec_mux_out(127-(c*32) downto 120-(c*32))) xor mul_b(dec_mux_out(119-(c*32) downto 112-(c*32))) xor mul_d(dec_mux_out(111-(c*32) downto 104-(c*32))) xor mul_9(dec_mux_out(103-(c*32) downto 96-(c*32)));
        imc_out_arr(c*4+1) <= mul_9(dec_mux_out(127-(c*32) downto 120-(c*32))) xor mul_e(dec_mux_out(119-(c*32) downto 112-(c*32))) xor mul_b(dec_mux_out(111-(c*32) downto 104-(c*32))) xor mul_d(dec_mux_out(103-(c*32) downto 96-(c*32)));
        imc_out_arr(c*4+2) <= mul_d(dec_mux_out(127-(c*32) downto 120-(c*32))) xor mul_9(dec_mux_out(119-(c*32) downto 112-(c*32))) xor mul_e(dec_mux_out(111-(c*32) downto 104-(c*32))) xor mul_b(dec_mux_out(103-(c*32) downto 96-(c*32)));
        imc_out_arr(c*4+3) <= mul_b(dec_mux_out(127-(c*32) downto 120-(c*32))) xor mul_d(dec_mux_out(119-(c*32) downto 112-(c*32))) xor mul_9(dec_mux_out(111-(c*32) downto 104-(c*32))) xor mul_e(dec_mux_out(103-(c*32) downto 96-(c*32)));
    end generate;

    -- Empaquetamos la salida de desencriptación (Salta InvMixCol en la última ronda)
    Gen_Dec_Out: for i in 0 to 15 generate
        dec_next(127 - (i*8) downto 120 - (i*8)) <= dec_mux_out(127 - (i*8) downto 120 - (i*8)) when ctrl_mux = '1' else imc_out_arr(i);
    end generate;


    -- =========================================================
    -- MUX PRINCIPAL: ¿ENCRIPTAMOS O DESENCRIPTAMOS?
    -- =========================================================
    next_state <= enc_next when enc_dec = '1' else dec_next;

    -- =========================================================
    -- REGISTRO SÍNCRONO
    -- =========================================================
    process(clk)
    begin
        if rising_edge(clk) then
            if load_init = '1' then
                -- RONDA INICIAL (Aplica igual para Enc y Dec: XOR con la primera llave)
                current_state <= data_in xor round_key;
            else
                current_state <= next_state;
            end if;
        end if;
    end process;

    -- Salida
    data_out <= current_state;

end Behavioral;