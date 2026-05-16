library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- ==========================================
-- Bloque de Memoria RAM
-- 256 posiciones x 16 bits (En este caso usas 32 bits en data)
-- Escritura síncrona, lectura asíncrona.
-- ==========================================
entity ram_block is
    Port (
        clk      : in  STD_LOGIC;
        we       : in  STD_LOGIC;                     -- write enable
        addr     : in  STD_LOGIC_VECTOR(15 downto 0); -- dirección (MAR la provee)
        data_in  : in  STD_LOGIC_VECTOR(31 downto 0); -- dato a escribir (viene del GPR)
        data_out : out STD_LOGIC_VECTOR(31 downto 0)  -- dato leído (va al GPR)
    );
end ram_block;

architecture Behavioral of ram_block is

    -- 256 posiciones es suficiente para simulación.
    -- Para más memoria cambia 255 por el tamaño que necesites (ej. 65535 para 64K).
    type ram_type is array (0 to 255) of STD_LOGIC_VECTOR(31 downto 0);
    signal RAM : ram_type := (
        0 => x"3243f6a8", -- Palabra 0
        1 => x"885a308d", -- Palabra 1
        2 => x"313198a2", -- Palabra 2
        3 => x"e0370734", -- Palabra 3
        others => (others => '0')
    );

begin

    -- Escritura síncrona
    process(clk)
    begin
        if rising_edge(clk) then
            if we = '1' then
                RAM(to_integer(unsigned(addr(7 downto 0)))) <= data_in;
            end if;
        end if;
    end process;

    -- Lectura asíncrona
    data_out <= RAM(to_integer(unsigned(addr(7 downto 0))));

end Behavioral;