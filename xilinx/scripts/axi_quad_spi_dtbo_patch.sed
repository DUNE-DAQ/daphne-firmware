/axi_quad_spi@9c020000 {/,/};/{
    /};/i\
                #address-cells = <1>;\
                #size-cells = <0>;\
                spidev@0 {\
                    status = "okay";\
                    compatible = "rohm,dh2228fv";\
                    spi-max-frequency = <50000000>;\
                    reg = <0>;\
                };
}
