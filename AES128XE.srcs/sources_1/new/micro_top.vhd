library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity micro_top is
    Port (
        clk      : in  STD_LOGIC;
        rst      : in  STD_LOGIC;
        start    : in  STD_LOGIC;
        enc_dec  : in  STD_LOGIC;
        key_in   : in  STD_LOGIC_VECTOR(127 downto 0);
        data_out : out STD_LOGIC_VECTOR(127 downto 0);
        done     : out STD_LOGIC
    );
end micro_top;

architecture Structural of micro_top is

    -- ==========================================
    -- COMPONENTES
    -- ==========================================
    component aes_fsm
        Port (
            clk       : in  STD_LOGIC;
            rst       : in  STD_LOGIC;
            start     : in  STD_LOGIC;
            enc_dec   : in  STD_LOGIC;
            ready     : in  STD_LOGIC;
            round_num : out STD_LOGIC_VECTOR(3 downto 0);
            ctrl_mux  : out STD_LOGIC;
            load_key  : out STD_LOGIC;
            load_init : out STD_LOGIC;
            done      : out STD_LOGIC
        );
    end component;

    component pc_reg
        Port (
            clk     : in  STD_LOGIC;
            rst     : in  STD_LOGIC;
            load_pc : in  STD_LOGIC;
            pc_in   : in  STD_LOGIC_VECTOR(15 downto 0);
            pc_out  : out STD_LOGIC_VECTOR(15 downto 0)
        );
    end component;

    component mar_reg
        Port (
            clk      : in  STD_LOGIC;
            rst      : in  STD_LOGIC;
            load     : in  STD_LOGIC;
            addr_in  : in  STD_LOGIC_VECTOR(15 downto 0);
            addr_out : out STD_LOGIC_VECTOR(15 downto 0)
        );
    end component;

    component gpr_bank
        Port (
            clk      : in  STD_LOGIC;
            rst      : in  STD_LOGIC;
            we       : in  STD_LOGIC;
            rd_addr1 : in  STD_LOGIC_VECTOR(2 downto 0);
            rd_addr2 : in  STD_LOGIC_VECTOR(2 downto 0);
            wr_addr  : in  STD_LOGIC_VECTOR(2 downto 0);
            data_in  : in  STD_LOGIC_VECTOR(31 downto 0);
            data_out1: out STD_LOGIC_VECTOR(31 downto 0);
            data_out2: out STD_LOGIC_VECTOR(31 downto 0)
        );
    end component;

    component ram_block
        Port (
            clk      : in  STD_LOGIC;
            we       : in  STD_LOGIC;
            addr     : in  STD_LOGIC_VECTOR(15 downto 0);
            data_in  : in  STD_LOGIC_VECTOR(31 downto 0);
            data_out : out STD_LOGIC_VECTOR(31 downto 0)
        );
    end component;

    component key_expansion
        Port (
            clk       : in  STD_LOGIC;
            rst       : in  STD_LOGIC;
            load_key  : in  STD_LOGIC;
            key_in    : in  STD_LOGIC_VECTOR(127 downto 0);
            round_num : in  STD_LOGIC_VECTOR(3 downto 0);
            ready     : out STD_LOGIC;
            round_key : out STD_LOGIC_VECTOR(127 downto 0)
        );
    end component;

    -- CAMBIO: Añadimos el componente de la ALU en lugar del datapath crudo
    component ALU_Crypto_128
        Port (
            clk         : in  STD_LOGIC;
            opcode      : in  STD_LOGIC_VECTOR(2 downto 0);
            operand_a   : in  STD_LOGIC_VECTOR(127 downto 0);
            operand_b   : in  STD_LOGIC_VECTOR(127 downto 0);
            alu_out     : out STD_LOGIC_VECTOR(127 downto 0)
        );
    end component;

    -- ==========================================
    -- SEÑALES INTERNAS
    -- ==========================================

    -- AES / FSM
    signal sig_round_num  : STD_LOGIC_VECTOR(3 downto 0);
    signal sig_round_key  : STD_LOGIC_VECTOR(127 downto 0);
    signal sig_ctrl_mux   : STD_LOGIC;
    signal sig_load_key   : STD_LOGIC;
    signal sig_load_init  : STD_LOGIC;
    signal sig_ready      : STD_LOGIC;

    -- CAMBIO: Bus de control para la ALU
    signal sig_opcode     : STD_LOGIC_VECTOR(2 downto 0);

    -- Ciclo de fetch
    signal sig_pc_out     : STD_LOGIC_VECTOR(15 downto 0);
    signal sig_mar_out    : STD_LOGIC_VECTOR(15 downto 0);
    signal sig_mem_dout   : STD_LOGIC_VECTOR(31 downto 0);

    -- GPR
    signal sig_gpr_dout1  : STD_LOGIC_VECTOR(31 downto 0);
    signal sig_gpr_dout2  : STD_LOGIC_VECTOR(31 downto 0);

    -- Registro ensamblador
    signal sig_data_block : STD_LOGIC_VECTOR(127 downto 0);
    signal word_count     : unsigned(1 downto 0);  
    signal block_ready    : STD_LOGIC;             

begin

    -- ==========================================
    -- INSTANCIACIONES
    -- ==========================================

    Control_Unit: aes_fsm
        Port map (
            clk       => clk,
            rst       => rst,
            start     => start,
            enc_dec   => enc_dec,
            ready     => sig_ready,
            round_num => sig_round_num,
            ctrl_mux  => sig_ctrl_mux,
            load_key  => sig_load_key,
            load_init => sig_load_init,
            done      => done
        );

    PC: pc_reg
        Port map (
            clk     => clk,
            rst     => rst,
            load_pc => '0',
            pc_in   => (others => '0'),
            pc_out  => sig_pc_out
        );

    MAR: mar_reg
        Port map (
            clk      => clk,
            rst      => rst,
            load     => '1',
            addr_in  => sig_pc_out,
            addr_out => sig_mar_out
        );

    Memoria: ram_block
        Port map (
            clk      => clk,
            we       => '0',
            addr     => sig_mar_out,
            data_in  => sig_gpr_dout1,
            data_out => sig_mem_dout
        );

    GPR: gpr_bank
        Port map (
            clk       => clk,
            rst       => rst,
            we        => '0',
            rd_addr1  => "000",
            rd_addr2  => "001",
            wr_addr   => "010",
            data_in   => sig_mem_dout,
            data_out1 => sig_gpr_dout1,
            data_out2 => sig_gpr_dout2
        );

    Key_Gen: key_expansion
        Port map (
            clk       => clk,
            rst       => rst,
            load_key  => sig_load_key,
            key_in    => key_in,
            round_num => sig_round_num,
            ready     => sig_ready,
            round_key => sig_round_key
        );

    -- =========================================================
    -- CAMBIO: TRADUCTOR DE SEÑALES A OPCODE DE LA ALU
    -- =========================================================
    process(sig_load_init, enc_dec, sig_ctrl_mux)
    begin
        if sig_load_init = '1' then
            sig_opcode <= "010"; -- Opcode: AES_INIT
        elsif enc_dec = '1' then
            if sig_ctrl_mux = '1' then
                sig_opcode <= "100"; -- Opcode: AES_ENC_LAST (Última ronda encriptar)
            else
                sig_opcode <= "011"; -- Opcode: AES_ENC_R (Ronda normal encriptar)
            end if;
        else
            if sig_ctrl_mux = '1' then
                sig_opcode <= "110"; -- Opcode: AES_DEC_LAST (Última ronda desencriptar)
            else
                sig_opcode <= "101"; -- Opcode: AES_DEC_R (Ronda normal desencriptar)
            end if;
        end if;
    end process;

    -- =========================================================
    -- CAMBIO: INSTANCIACIÓN DE LA ALU
    -- =========================================================
    ALU_Unit: ALU_Crypto_128
        Port map (
            clk         => clk,
            opcode      => sig_opcode,
            operand_a   => sig_data_block, -- Datos ensamblados desde la RAM
            operand_b   => sig_round_key,  -- Llave de la ronda actual
            alu_out     => data_out        -- Salida final del sistema
        );

    -- ==========================================
    -- REGISTRO ENSAMBLADOR DE 128 BITS
    -- ==========================================
    process(clk, rst)
    begin
        if rst = '1' then
            sig_data_block <= (others => '0');
            word_count     <= (others => '0');
            block_ready    <= '0';

        elsif rising_edge(clk) then
            block_ready <= '0';

            case word_count is
                when "00" =>
                    sig_data_block(127 downto 96) <= sig_mem_dout;
                    word_count <= word_count + 1;
                when "01" =>
                    sig_data_block(95 downto 64)  <= sig_mem_dout;
                    word_count <= word_count + 1;
                when "10" =>
                    sig_data_block(63 downto 32)  <= sig_mem_dout;
                    word_count <= word_count + 1;
                when "11" =>
                    sig_data_block(31 downto 0)   <= sig_mem_dout;
                    word_count <= (others => '0');
                    block_ready <= '1';  
                when others =>
                    word_count <= (others => '0');
            end case;
        end if;
    end process;

end Structural;