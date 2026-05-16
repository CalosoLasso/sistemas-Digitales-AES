library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- ==========================================
-- ENTIDAD: ALU con soporte AES
-- ==========================================
entity ALU_Crypto_128 is
    Port (
        clk         : in  STD_LOGIC;
        opcode      : in  STD_LOGIC_VECTOR(2 downto 0);   -- Selector de operación
        operand_a   : in  STD_LOGIC_VECTOR(127 downto 0); -- Entrada de Datos (Data In)
        operand_b   : in  STD_LOGIC_VECTOR(127 downto 0); -- Segunda entrada / Llave (Round Key)
        alu_out     : out STD_LOGIC_VECTOR(127 downto 0)  -- Resultado final
    );
end ALU_Crypto_128;

architecture Behavioral of ALU_Crypto_128 is

    -- 1. Declaración de tu componente original AES Datapath
    component aes_datapath is
        Port (
            clk         : in  STD_LOGIC;
            load_init   : in  STD_LOGIC;
            enc_dec     : in  STD_LOGIC;
            ctrl_mux    : in  STD_LOGIC;
            data_in     : in  STD_LOGIC_VECTOR(127 downto 0); 
            round_key   : in  STD_LOGIC_VECTOR(127 downto 0); 
            data_out    : out STD_LOGIC_VECTOR(127 downto 0)  
        );
    end component;

    -- Señales de control para el módulo AES
    signal aes_load_init : STD_LOGIC;
    signal aes_enc_dec   : STD_LOGIC;
    signal aes_ctrl_mux  : STD_LOGIC;
    
    -- Señales de salida internas
    signal aes_result    : STD_LOGIC_VECTOR(127 downto 0);
    signal logic_result  : STD_LOGIC_VECTOR(127 downto 0);

begin

    -- =========================================================
    -- INSTANCIACIÓN DEL DATAPATH AES
    -- =========================================================
    AES_UNIT: aes_datapath
        Port map (
            clk         => clk,
            load_init   => aes_load_init,
            enc_dec     => aes_enc_dec,
            ctrl_mux    => aes_ctrl_mux,
            data_in     => operand_a,
            round_key   => operand_b,
            data_out    => aes_result
        );

    -- =========================================================
    -- DECODIFICADOR DE OPCODES PARA SEÑALES DE CONTROL AES
    -- =========================================================
    -- Opcode 010: AES_INIT (Carga y XOR inicial)
    aes_load_init <= '1' when (opcode = "010") else '0';
    
    -- Opcodes 011 y 100: Encriptación (1), Opcodes 101 y 110: Desencriptación (0)
    aes_enc_dec   <= '1' when (opcode = "011" or opcode = "100") else '0';
    
    -- Opcodes 100 y 110: Última ronda (Salta MixColumns)
    aes_ctrl_mux  <= '1' when (opcode = "100" or opcode = "110") else '0';


    -- =========================================================
    -- OPERACIONES LÓGICAS ESTÁNDAR (Combinacionales)
    -- =========================================================
    process(opcode, operand_a, operand_b)
    begin
        case opcode is
            when "000" => 
                logic_result <= operand_a and operand_b; -- AND de 128 bits
            when "001" => 
                logic_result <= operand_a xor operand_b; -- XOR de 128 bits
            when others =>
                logic_result <= (others => '0');
        end case;
    end process;


    -- =========================================================
    -- MUX DE SALIDA PRINCIPAL DE LA ALU
    -- =========================================================
    -- Si el opcode corresponde a una operación AES (010 en adelante), 
    -- mostramos la salida del registro de estado del bloque AES.
    -- Si no, mostramos el resultado de las operaciones lógicas estándar.
    alu_out <= logic_result when (opcode = "000" or opcode = "001") else aes_result;

end Behavioral;