library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- ==========================================
-- 1. ENTIDAD: Los pines hacia el mundo exterior
-- ==========================================
entity aes_top is
    Port (
        clk      : in  STD_LOGIC;
        rst      : in  STD_LOGIC;
        start    : in  STD_LOGIC;
        enc_dec  : in  STD_LOGIC;
        data_in  : in  STD_LOGIC_VECTOR(127 downto 0);
        key_in   : in  STD_LOGIC_VECTOR(127 downto 0);
        
        data_out : out STD_LOGIC_VECTOR(127 downto 0);
        done     : out STD_LOGIC
    );
end aes_top;

-- ==========================================
-- 2. ARQUITECTURA: Conexiones internas
-- ==========================================
architecture Structural of aes_top is

    component aes_fsm
        Port (
            clk         : in  STD_LOGIC;
            rst         : in  STD_LOGIC;
            start       : in  STD_LOGIC;
            enc_dec     : in  STD_LOGIC;
            ready       : in  STD_LOGIC;
            round_num   : out STD_LOGIC_VECTOR(3 downto 0);
            ctrl_mux    : out STD_LOGIC;
            load_key    : out STD_LOGIC;
            load_init   : out STD_LOGIC;
            done        : out STD_LOGIC
        );
    end component;

    component key_expansion
        Port (
            clk        : in  STD_LOGIC;
            rst        : in  STD_LOGIC;
            load_key   : in  STD_LOGIC;
            key_in     : in  STD_LOGIC_VECTOR(127 downto 0);
            round_num  : in  STD_LOGIC_VECTOR(3 downto 0);
            ready      : out STD_LOGIC;
            round_key  : out STD_LOGIC_VECTOR(127 downto 0) 
        );
    end component;

    component aes_datapath
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

    -- SEÑALES INTERNAS
    signal sig_round_num : STD_LOGIC_VECTOR(3 downto 0);
    signal sig_round_key : STD_LOGIC_VECTOR(127 downto 0);
    signal sig_ctrl_mux  : STD_LOGIC;
    signal sig_load_key  : STD_LOGIC;
    signal sig_load_init : STD_LOGIC;
    signal sig_ready     : STD_LOGIC;

begin

    Control_Unit: aes_fsm
        Port map (
            clk       => clk,
            rst       => rst,
            start     => start,
            enc_dec   => enc_dec,       -- Conectado al exterior
            ready     => sig_ready,     -- Recibe el aviso del Key Gen
            round_num => sig_round_num,
            ctrl_mux  => sig_ctrl_mux,
            load_key  => sig_load_key,  
            load_init => sig_load_init, 
            done      => done
        );

    Key_Gen: key_expansion
        Port map (
            clk       => clk,
            rst       => rst,
            load_key  => sig_load_key,
            key_in    => key_in,
            round_num => sig_round_num,
            ready     => sig_ready,     -- Envía el aviso a la FSM
            round_key => sig_round_key
        );

    Datapath: aes_datapath
        Port map (
            clk       => clk,
            load_init => sig_load_init, -- Recibe la orden precisa de la FSM
            enc_dec   => enc_dec,       -- El Datapath ya sabe si rutear por SBOX o INVSBOX
            ctrl_mux  => sig_ctrl_mux,
            data_in   => data_in,
            round_key => sig_round_key,
            data_out  => data_out
        );

end Structural;