library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- ==========================================
-- Program Counter (PC)
-- Registro de 16 bits que guarda la dirección
-- de la siguiente instrucción a ejecutar.
-- ==========================================
entity pc_reg is
    Port (
        clk     : in  STD_LOGIC;
        rst     : in  STD_LOGIC;
        load_pc : in  STD_LOGIC;                     -- '1' = carga nueva dirección
        pc_in   : in  STD_LOGIC_VECTOR(15 downto 0); -- dirección a cargar
        pc_out  : out STD_LOGIC_VECTOR(15 downto 0)  -- dirección actual
    );
end pc_reg;

architecture Behavioral of pc_reg is
    signal pc_reg_s : STD_LOGIC_VECTOR(15 downto 0);
begin

    process(clk, rst)
    begin
        if rst = '1' then
            pc_reg_s <= (others => '0');

        elsif rising_edge(clk) then
            if load_pc = '1' then
                pc_reg_s <= pc_in;
            else
                -- Auto-incremento: avanza a la siguiente instrucción
                pc_reg_s <= std_logic_vector(unsigned(pc_reg_s) + 1);
            end if;
        end if;
    end process;

    pc_out <= pc_reg_s;

end Behavioral;