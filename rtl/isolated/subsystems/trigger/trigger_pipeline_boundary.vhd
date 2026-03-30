library ieee;
use ieee.std_logic_1164.all;
use work.daphne_subsystem_pkg.all;

entity trigger_pipeline_boundary is
  port (
    clk            : in  std_logic;
    reset          : in  std_logic;
    descriptor_o   : out trigger_descriptor_t;
    descriptor_rdy : in  std_logic
  );
end entity trigger_pipeline_boundary;

architecture rtl of trigger_pipeline_boundary is
begin
  -- Future home for the cleaned trigger/filter/descriptor boundary.
  descriptor_o <= TRIGGER_DESCRIPTOR_NULL;
end architecture rtl;
