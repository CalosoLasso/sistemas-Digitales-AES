library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- ==========================================
-- General Purpose Registers (GPR)
-- Banco de 8 registros de 16 bits.
-- 2 puertos de lectura simultánea,
-- 1 puerto de escritura síncrona.
-- ==========================================
entity gpr_bank is
    Port (
        clk      : in  STD_LOGIC;
        rst      : in  STD_LOGIC;
        we       : in  STD_LOGIC;                    -- write enable
        rd_addr1 : in  STD_LOGIC_VECTOR(2 downto 0); -- dirección lectura puerto 1
        rd_addr2 : in  STD_LOGIC_VECTOR(2 downto 0); -- dirección lectura puerto 2
        wr_addr  : in  STD_LOGIC_VECTOR(2 downto 0); -- dirección escritura
        data_in  : in  STD_LOGIC_VECTOR(31 downto 0);
        data_out1: out STD_LOGIC_VECTOR(31 downto 0);
        data_out2: out STD_LOGIC_VECTOR(31 downto 0)
    );
end gpr_bank;

architecture Behavioral of gpr_bank is

    type reg_array is array (0 to 7) of STD_LOGIC_VECTOR(31 downto 0);
    signal regs : reg_array;

begin

    -- Escritura síncrona
    process(clk, rst)
    begin
        if rst = '1' then
            regs <= (others => (others => '0'));

        elsif rising_edge(clk) then
            if we = '1' then
                regs(to_integer(unsigned(wr_addr))) <= data_in;
            end if;
        end if;
    end process;

    -- Lectura asíncrona (combinacional)
    data_out1 <= regs(to_integer(unsigned(rd_addr1)));
    data_out2 <= regs(to_integer(unsigned(rd_addr2)));

end Behavioral;