library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- ==========================================
-- Memory Address Register (MAR)
-- Guarda la dirección de memoria que se va
-- a leer o escribir en el siguiente ciclo.
-- ==========================================
entity mar_reg is
    Port (
        clk      : in  STD_LOGIC;
        rst      : in  STD_LOGIC;
        load     : in  STD_LOGIC;                     -- '1' = captura addr_in
        addr_in  : in  STD_LOGIC_VECTOR(15 downto 0);
        addr_out : out STD_LOGIC_VECTOR(15 downto 0)
    );
end mar_reg;

architecture Behavioral of mar_reg is
    signal mar_s : STD_LOGIC_VECTOR(15 downto 0);
begin

    process(clk, rst)
    begin
        if rst = '1' then
            mar_s <= (others => '0');

        elsif rising_edge(clk) then
            if load = '1' then
                mar_s <= addr_in;
            end if;
            -- Si load = '0', retiene el valor anterior
        end if;
    end process;

    addr_out <= mar_s;

end Behavioral;