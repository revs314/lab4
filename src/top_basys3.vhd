library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;


-- Lab 4
entity top_basys3 is
    port(
        -- inputs
        clk     :   in std_logic; -- native 100MHz FPGA clock
        sw      :   in std_logic_vector(15 downto 0);
        btnU    :   in std_logic; -- master_reset
        btnL    :   in std_logic; -- clk_reset
        btnR    :   in std_logic; -- fsm_reset
        
        -- outputs
        led :   out std_logic_vector(15 downto 0);
        -- 7-segment display segments (active-low cathodes)
        seg :   out std_logic_vector(6 downto 0);
        -- 7-segment display active-low enables (anodes)
        an  :   out std_logic_vector(3 downto 0)
    );
end top_basys3;

architecture top_basys3_arch of top_basys3 is

    -- signal declarations
    -- need a clock to slow down the program
    signal w_slow_clk : std_logic;
    
    -- need floor signal; 4 bits = 4 floors
    signal w_floor2 : std_logic_vector(3 downto 0); 
    
    signal w_floor1 : std_logic_vector(3 downto 0); 
    
    -- need output of 7 segments for the display
    signal w_seg : std_logic_vector(6 downto 0); 
    
    -- reset signal for clock
    signal w_clk_reset : std_logic;
    
    -- reset signal for elevator
    signal w_elev_reset : std_logic;
    
    -- tdm clock 
    signal w_tdm_clk : std_logic;
    
    -- tdm data
    signal w_tdm_data : std_logic_vector(3 downto 0);
    
    -- tdm sel
    signal w_tdm_sel : std_logic_vector(3 downto 0);
    
    
  
	-- component declarations
    component sevenseg_decoder is
        port (
            i_Hex : in STD_LOGIC_VECTOR (3 downto 0);
            o_seg_n : out STD_LOGIC_VECTOR (6 downto 0)
        );
    end component sevenseg_decoder;
    
    component elevator_controller_fsm is
		Port (
            i_clk        : in  STD_LOGIC;
            i_reset      : in  STD_LOGIC;
            is_stopped   : in  STD_LOGIC;
            go_up_down   : in  STD_LOGIC;
            o_floor : out STD_LOGIC_VECTOR (3 downto 0)		   
		 );
	end component elevator_controller_fsm;
	
	component TDM4 is
		generic ( constant k_WIDTH : natural  := 4); -- bits in input and output
        Port ( i_clk		: in  STD_LOGIC;
           i_reset		: in  STD_LOGIC; -- asynchronous
           i_D3 		: in  STD_LOGIC_VECTOR (k_WIDTH - 1 downto 0);
		   i_D2 		: in  STD_LOGIC_VECTOR (k_WIDTH - 1 downto 0);
		   i_D1 		: in  STD_LOGIC_VECTOR (k_WIDTH - 1 downto 0);
		   i_D0 		: in  STD_LOGIC_VECTOR (k_WIDTH - 1 downto 0);
		   o_data		: out STD_LOGIC_VECTOR (k_WIDTH - 1 downto 0);
		   o_sel		: out STD_LOGIC_VECTOR (3 downto 0)	-- selected data line (one-cold)
	   );
    end component TDM4;
     
	component clock_divider is
        generic ( constant k_DIV : natural := 2	); -- How many clk cycles until slow clock toggles
                                                   -- Effectively, you divide the clk double this 
                                                   -- number (e.g., k_DIV := 2 --> clock divider of 4)
        port ( 	i_clk    : in std_logic;
                i_reset  : in std_logic;		   -- asynchronous
                o_clk    : out std_logic		   -- divided (slow) clock
        );
    end component clock_divider;
	
begin
	-- PORT MAPS ----------------------------------------
	-- created port maps for elevator and seven seg and clock
	
	tdm_inst : TDM4
	   port map (						  
            i_clk   => w_tdm_clk,
			i_reset => btnU,
			i_D3 => x"F",
			i_D2 => w_floor1,
			i_D1 => x"F",
			i_D0 => w_floor2,
			o_data => w_tdm_data,
			o_sel => w_tdm_sel
	    );
	
	elevator1_inst : elevator_controller_fsm 		--instantiation of elevator 1
        port map (						  
            i_clk   => w_slow_clk,
			i_reset => w_elev_reset,
			-- use R for reset for elevator
			is_stopped  => sw(12),
			go_up_down     => sw(13),
            o_floor => w_floor1
	    );
	
	elevator2_inst : elevator_controller_fsm 		--instantiation of elevator 2
        port map (						  
            i_clk   => w_slow_clk,
			i_reset => w_elev_reset,
			-- use R for reset for elevator
			is_stopped  => sw(14),
			go_up_down     => sw(15),
            o_floor => w_floor2
	    );

	sevenseg_inst : sevenseg_decoder
	   port map (
	       -- the hex is the input of sevenseg that takes in the floors
	       -- it'll be outputting the tdm data
	       -- tdm cycles through each of the displays really fast (F, elev1, F, elev2)
	       i_Hex => w_tdm_data,
	       -- the seg is the output of sevenseg that outputs seg
	       o_seg_n => w_seg
	    );
	
    -- put clock in to slow down
        clkdiv_inst : clock_divider 		--instantiation of clock_divider to take 
        generic map ( k_DIV => 25000000 ) -- 1 Hz clock from 100 MHz (0.5 sec)
        port map (						  
            i_clk   => clk,
            i_reset => w_clk_reset,
            -- use different button for clock reset
            -- pressing L restarts the slow clock
            o_clk   => w_slow_clk
            
        );  
        
     -- tdm clock
     tdm_clkdiv_inst : clock_divider 		--instantiation of clock_divider to take 
        generic map ( k_DIV => 5000 ) -- really fast
        port map (						  
            i_clk   => clk,
            i_reset => btnU,
            o_clk   => w_tdm_clk
        );  
        
        
        
	
	-- CONCURRENT STATEMENTS ----------------------------
	-- 3 anodes
        -- an(3:0)
        -- an3 is leftmost: F
        -- an2: elevator 1
        -- an1: F
        -- an0 is rightmost: elevator 2
    -- whichever one the tdm is currently on, output that on the board (the sel selects what display to put on)
        -- connecting to the anode means the anodes will act like the tdm and focus on one display at a time
    an <= w_tdm_sel;
	
	-- turns on the display
	seg <= w_seg;
	
	-- LED 15 gets the FSM slow clock signal
	led(15) <= w_slow_clk;
	
	-- The rest are grounded
	led(14 downto 8) <= (others => '0');
	
	-- see the elevator moving
	--elevator 1
	led(3 downto 0) <= w_floor1;
	--elevator 2
	led(7 downto 4) <= w_floor2;
	
	
	
	
	
	
	
	
	-- leave unused switches UNCONNECTED. Ignore any warnings this causes.
	
	-- reset signals
	
	-- reset for clock
	w_clk_reset <= btnU or btnL;
	
	-- reset for elev
	w_elev_reset <= btnU or btnR;
	
end top_basys3_arch;









