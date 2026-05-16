library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- ==========================================
-- ENTIDAD: Unidad de Control (FSM)
-- ==========================================
entity aes_fsm is
    Port (
        clk         : in  STD_LOGIC;
        rst         : in  STD_LOGIC;
        start       : in  STD_LOGIC;
        enc_dec     : in  STD_LOGIC; -- '1' = Encriptar, '0' = Desencriptar
        ready       : in  STD_LOGIC; -- '1' = El generador de claves ya terminó
        
        round_num   : out STD_LOGIC_VECTOR(3 downto 0); 
        ctrl_mux    : out STD_LOGIC; -- Salta MixColumns en la última ronda
        load_key    : out STD_LOGIC; -- Inicia el pre-cálculo de claves
        load_init   : out STD_LOGIC; -- Avisa al Datapath que haga el primer AddRoundKey
        load_pc     : out std_logic;
        done        : out STD_LOGIC
    );
end aes_fsm;

-- ==========================================
-- ARQUITECTURA
-- ==========================================
architecture Behavioral of aes_fsm is

    type state_type is (IDLE, WAIT_KEY, DO_ROUNDS, DO_FINAL, FINISHED);
    signal current_state : state_type;
    signal round_counter : unsigned(3 downto 0);

begin

    process(clk, rst)
    begin
        if rst = '1' then
            current_state <= IDLE;
            round_counter <= (others => '0');
            round_num     <= (others => '0');
            ctrl_mux      <= '0';
            load_key      <= '0';
            load_init     <= '0';
            load_pc       <= '0';
            done          <= '0';
            
        elsif rising_edge(clk) then
            -- Valores por defecto
            load_key  <= '0';
            load_init <= '0';
            load_pc   <= '0';
            done      <= '0';
            ctrl_mux  <= '0';
            round_num <= std_logic_vector(round_counter);

            case current_state is
                
                when IDLE =>
                    if start = '1' then
                        load_key <= '1'; -- Mandamos a calcular todas las llaves
                        current_state <= WAIT_KEY;
                        -- Elegimos la llave inicial dependiendo del modo
                        if enc_dec = '1' then
                            round_counter <= to_unsigned(0, 4);
                        else
                            round_counter <= to_unsigned(10, 4);
                        end if;
                    end if;

                when WAIT_KEY =>
                    if ready = '1' then
                        load_init <= '1';
                        load_pc   <= '1';   -- <-- carga la dirección inicial en PC y MAR
                        current_state <= DO_ROUNDS;
                        
                        if enc_dec = '1' then
                            round_counter <= to_unsigned(1, 4);
                        else
                            round_counter <= to_unsigned(9, 4);
                        end if;
                    end if;

                when DO_ROUNDS =>
                    if enc_dec = '1' then
                        -- Encriptar: Contamos hacia arriba hasta llegar a la 9
                        if round_counter = 9 then
                            round_counter <= round_counter + 1;
                            current_state <= DO_FINAL;
                        else
                            round_counter <= round_counter + 1;
                        end if;
                    else
                        -- Desencriptar: Contamos hacia abajo hasta llegar a la 1
                        if round_counter = 1 then
                            round_counter <= round_counter - 1;
                            current_state <= DO_FINAL;
                        else
                            round_counter <= round_counter - 1;
                        end if;
                    end if;

                when DO_FINAL =>
                    ctrl_mux <= '1'; -- Activa el salto de MixColumns para la última ronda
                    current_state <= FINISHED;

                when FINISHED =>
                    done <= '1';
                    current_state <= IDLE;
                    
                when others =>
                    current_state <= IDLE;
                    
            end case;
        end if;
    end process;

end Behavioral;