module part2
    (   CLOCK_50,                       //  On Board 50 MHz
        // Your inputs and outputs here
        KEY,
        PS2_CLK,
        PS2_DAT,
        // The ports below are for the VGA output.  Do not change.
        VGA_CLK,                        //  VGA Clock
        VGA_HS,                         //  VGA H_SYNC
        VGA_VS,                         //  VGA V_SYNC
        VGA_BLANK_N,                        //  VGA BLANK
        VGA_SYNC_N,                     //  VGA SYNC
        VGA_R,                          //  VGA Red[9:0]
        VGA_G,                          //  VGA Green[9:0]
        VGA_B         //  VGA Blue[9:0]
    );
    input         CLOCK_50;             //  50 MHz
    input   [3:0] KEY;

    inout PS2_CLK;
    inout PS2_DAT;

    // Declare your inputs and outputs here
    // Do not change the following outputs
    output          VGA_CLK;                //  VGA Clock
    output          VGA_HS;                 //  VGA H_SYNC
    output          VGA_VS;                 //  VGA V_SYNC
    output          VGA_BLANK_N;                //  VGA BLANK
    output          VGA_SYNC_N;             //  VGA SYNC
    output  [9:0]   VGA_R;                  //  VGA Red[9:0]
    output  [9:0]   VGA_G;                  //  VGA Green[9:0]
    output  [9:0]   VGA_B;                  //  VGA Blue[9:0]
    
    wire resetn;
    assign resetn = KEY[0];
    
    // Create the colour, x, y and writeEn wires that are inputs to the controller.
    wire [2:0] colour;
    wire [7:0] x;
    wire [6:0] y;
    wire writeEn;

    // Create an Instance of a VGA controller - there can be only one!
    // Define the number of colours as well as the initial background
    // image file (.MIF) for the controller.
    vga_adapter VGA(
            .resetn(resetn),
            .clock(CLOCK_50),
            .colour(colour),
            .x(x),
            .y(y),
            .plot(writeEn),
            /* Signals for the DAC to drive the monitor. */
            .VGA_R(VGA_R),
            .VGA_G(VGA_G),
            .VGA_B(VGA_B),
            .VGA_HS(VGA_HS),
            .VGA_VS(VGA_VS),
            .VGA_BLANK(VGA_BLANK_N),
            .VGA_SYNC(VGA_SYNC_N),
            .VGA_CLK(VGA_CLK));
        defparam VGA.RESOLUTION = "160x120";
        defparam VGA.MONOCHROME = "FALSE";
        defparam VGA.BITS_PER_COLOUR_CHANNEL = 1;
        defparam VGA.BACKGROUND_IMAGE = "black.mif";
            
    // Put your code here. Your code should produce signals x,y,colour and writeEn/plot
    // for the VGA controller, in addition to any other functionality your design may require.

    wire w, a, s, d, left, right, up, down, space, enter;
    // Wires

    keyboard_tracker #(.PULSE_OR_HOLD(1)) k0(
        .clock(CLOCK_50),
        .reset(resetn),
        .PS2_CLK(PS2_CLK),
        .PS2_DAT(PS2_DAT),
        .w(w),
        .a(a),
        .s(s),
        .d(d),
        .left(left),
        .right(right),
        .up(up),
        .down(down),
        .space(space),
        .enter(enter)
    );
    
    wire [1:0] dir;

    // Datapath
    datapath d0(
        .direction(dir),
        .space(space),
        .clk(CLOCK_50),
        .resetn(resetn),
        .x(x),
        .y(y),
        .colour(colour),
        .writeEn(writeEn)
    );
     
    // Control
    control c0(
        .clk(CLOCK_50),
        .resetn(resetn),
        .w(w),
        .a(a),
        .s(s),
        .d(d),
        .direction(dir)
    );

endmodule

module control(
    input clk,
    input resetn,
    input w,
    input a,
    input s,
    input d,

    output reg [1:0] direction
    );

    reg [1:0] current_state, next_state; 

    localparam  UP      = 2'd0,
                RIGHT   = 2'd1,
                DOWN    = 2'd2,
                LEFT    = 2'd3;
    
    // Next state logic aka our state table
    always@(*)
    begin: state_table 
            case (current_state)
                RIGHT: begin
                    if (w) next_state = UP;
                    else if (s) next_state = DOWN;
                    else next_state = RIGHT;
                end
                DOWN: begin
                    if (d) next_state = RIGHT;
                    else if (a) next_state = LEFT;
                    else next_state = DOWN;
                end
                LEFT: begin
                    if (w) next_state = UP;
                    else if (s) next_state = DOWN;
                    else next_state = LEFT;
                end
                UP: begin
                    if (a) next_state = LEFT;
                    else if (d) next_state = RIGHT;
                    else next_state = UP;
                end
            default: next_state = RIGHT;
        endcase
    end // state_table
   

    // Output logic aka all of our datapath control signals
    always @(*)
    begin: enable_signals
        // By default make all our signals 0
        direction = 2'b00;

        case (current_state)
            UP: begin
                direction = 2'b00;
            end
            RIGHT: begin
                direction = 2'b01;
            end
            DOWN: begin
                direction = 2'b10;
            end
            LEFT: begin 
                direction = 2'b11;
            end
            
        // default:    // don't need default since we already made sure all of our outputs were assigned a value at the start of the always block
        endcase
    end // enable_signals
     
    // current_state registers
    always@(posedge clk)
    begin: state_FFs
        if(!resetn)
            current_state <= RIGHT;
        else
            current_state <= next_state;
    end // state_FFS
endmodule

module datapath (direction, space, clk, resetn, x , y, colour, writeEn);
    input [1:0] direction;
    input space, clk, resetn;
    output reg [7:0] x;
    output reg [6:0] y;
    output [2:0] colour;
    output reg writeEn;
    
    wire body_done;
    wire shift_extend_done;
    wire extend_done;
    wire draw_body_done;
    
    wire [7:0] headXwire, tailXwire, bodyXwire, drawBodyXwire;
    wire [6:0] headYwire, tailYwire, bodyYwire, drawBodyYwire;
    wire draw_pixel_enable_ram_wire;
    
    reg [7:0] appleXreg;
    reg [6:0] appleYreg;
    
    wire pixel_done_wire;
    wire pixel_done;
    
    wire fill_done;
    wire [7:0] fillXwire;
    wire [6:0] fillYwire;
    wire fill_write_wire;

    wire slow_clk;
    rate_divider rd0(
        .clk(clk),
        .resetn(resetn),
        .clk_out(slow_clk)
    );

    wire [7:0] new_head_x_wire;
    wire [6:0] new_head_y_wire;
    new_head nh0(
        .clk(clk),
        .resetn(resetn),
        .direction(direction),
        .head_x(headXwire),
        .head_y(headYwire),
        .new_head_x(new_head_x_wire),
        .new_head_y(new_head_y_wire)
    );
    
    wire [7:0] final_new_head_x_wire;
    wire [6:0] final_new_head_y_wire;
    wire [1:0] decision_wire;
    decision d0(
        .clk(clk),
        .resetn(resetn),
        .head_x(headXwire),
        .head_y(headYwire),
        .tail_x(tailXwire),
        .tail_y(tailYwire),
        .apple_x(appleXreg),
        .apple_y(appleYreg),
        .ram_x(bodyXwire),
        .ram_y(bodyYwire),
        .ram_done(body_done),
        .new_head_x(final_new_head_x_wire),
        .new_head_y(final_new_head_y_wire),
        .d(decision_wire)
    );

    reg done;
    wire select_draw_wire, draw_body_signal_wire, draw_pixel_enable_wire, draw_screen_wire, load_apple_coord_wire;
    wire shift_extend_wire, extend_wire;
    wire [1:0] select_pixel_wire;
    wire [2:0] colour_wire;
    wire RESET_ALL_WIRE;
    inner_fsm f0(
        .clk(clk),
        .slow_clk(slow_clk),
        .resetn(resetn),
        .space(space),
        .decision(decision_wire),
        .done(done),
        .draw_screen(draw_screen_wire),
        .draw_pixel_enable(draw_pixel_enable_wire),
        .colour(colour_wire),
        .load_apple_coord(load_apple_coord_wire),
        .select_draw_source(select_draw_wire),
        .select_pixel_source(select_pixel_wire),
        .shift_extend(shift_extend_wire),
        .extend(extend_wire),
        .draw_body_signal(draw_body_signal_wire),
        .reset_all(RESET_ALL_WIRE)
    );


    pseudoram ps0(
        .resetn(resetn),
        .clk(clk),
        .slow_clk(slow_clk),
        .shift_extend(shift_extend_wire),
        .extend(extend_wire),
        .draw_body(draw_body_signal_wire),
        .pixel_done(pixel_done_wire * draw_body_signal_wire),
        .new_headX(final_new_head_x_wire),
        .new_headY(final_new_head_y_wire),
        .bodyX(bodyXwire),
        .bodyY(bodyYwire),
        .draw_bodyX(drawBodyXwire),
        .draw_bodyY(drawBodyYwire),
        .body_done(body_done),
        .shift_extend_done(shift_extend_done),
        .extend_done(extend_done),
        .draw_body_done(draw_body_done),
        .draw_pixel_enable(draw_pixel_enable_ram_wire),
        .headX(headXwire),
        .headY(headYwire),
        .tailX(tailXwire),
        .tailY(tailYwire)
    );

    wire [5:0] lsfrXwire;
    wire [5:0] lsfrYwire;

    lsfr lsfrX(
        .clk(clk),
        .reset(resetn),
        .seed(7'b1010101),
        .out(lsfrXwire)
    );
    lsfr lsfrY(
        .clk(clk),
        .reset(resetn),
        .seed(7'b111001),
        .out(lsfrYwire)
    );

//apple registers


    always @ (posedge clk) begin
        done <= draw_body_done | shift_extend_done | extend_done | (pixel_done_wire * (1 - draw_body_signal_wire)) | fill_done;
        if (!resetn) begin
            appleXreg <= 7'd0;
            appleYreg <= 6'd0;
            done <= 0;
        end
        else begin
            if (load_apple_coord_wire) begin
                appleXreg <= {1'b0, {lsfrXwire, 1'b0}};
                appleYreg <= {1'b0, lsfrYwire << 1};
            end
        end
    end
    
    fill_screen fs0(
        .clk(clk),
        .resetn(resetn),
        .en(draw_screen_wire),
        .x(fillXwire),
        .y(fillYwire),
        .writeEn(fill_write_wire),
        .done(fill_done)
    );

    reg [7:0] pixelX;
    reg [6:0] pixelY;
    //pixelXmux
    always @(*)
    begin
        case(select_pixel_wire[1:0])
            2'b00: pixelX = headXwire;
            2'b01: pixelX = tailXwire;
            2'b10: pixelX = appleXreg;
            2'b11: pixelX = drawBodyXwire;
            default: pixelX = headXwire;
        endcase
    end

    //pixelymux
    always @(*)
    begin
        case(select_pixel_wire[1:0])
            2'b00: pixelY = headYwire;
            2'b01: pixelY = tailYwire;
            2'b10: pixelY = appleYreg;
            2'b11: pixelY = drawBodyYwire;
            default: pixelY = headYwire;
        endcase
    end

    //enable_mux

    
    wire [7:0] drawXwire;
    wire [6:0] drawYwire;
    wire draw_write_wire;
    
    draw2by2 d2b2(
        .clk(clk),
        .en(draw_pixel_enable_wire || draw_pixel_enable_ram_wire),
        .reset(resetn),
        .x(pixelX),
        .y(pixelY),
        .x_out(drawXwire),
        .y_out(drawYwire),
        .done(pixel_done_wire),
        .writeEn(draw_write_wire)
    );


    //pixelXmux, pixelYmux, pixel_screen_x_mux, pixel_screen_y_mux, write_mux

    //pixel_screen_x_mux
    always @(*)
    begin
        case(select_draw_wire)
            1'b0: x = drawXwire;
            1'b1: x = fillXwire;
            default: x = drawXwire;
        endcase
    end
    //pixel_screen_y_mux
    always @(*)
    begin
        case(select_draw_wire)
            1'b0: y = drawYwire;
            1'b1: y = fillYwire;
            default: y = drawYwire;
        endcase
    end

    //write_mux
    always @(*)
    begin
        case(select_draw_wire)
            1'b0: writeEn = draw_write_wire;
            1'b1: writeEn = fill_write_wire;
            default: writeEn = draw_write_wire;
        endcase
    end
    
endmodule

module inner_fsm(
    // TODO: MAKE SURE TO CHANGE INPUTS ETC AS NECESSARY
    input clk,
    input slow_clk,
    input resetn,
    input space,
    input [1:0] decision,
    input done,

    output reg  draw_screen,
    output reg  draw_pixel_enable,
    output reg  draw_body_signal,
    output reg  [2:0] colour,
    output reg  load_apple_coord,
    output reg  [1:0] select_pixel_source, // 00 = head, 01 == tail, 10 == apple, 11 == body
    output reg  select_draw_source, // 0 = pixel, 1 = screen
    output reg  shift_extend,
    output reg  extend,
    output reg  reset_all
    );

    reg [5:0] current_state, next_state; 

    localparam  BEFORE_GAME                 = 6'd0,
                DRAW_WHITE                  = 6'd1,
                DRAW_WHITE_WAIT             = 6'd2,
                DRAW_SNAKE                  = 6'd3,
                DRAW_SNAKE_WAIT             = 6'd4,
                LOAD_FIRST_APPLE_COORD      = 6'd5,
                LOAD_FIRST_APPLE_COORD_WAIT = 6'd6,
                DRAW_FIRST_APPLE            = 6'd7,
                DRAW_FIRST_APPLE_WAIT       = 6'd8,
                WAIT_FOR_DECISION           = 6'd9,
                ERASE_TAIL                  = 6'd10,
                ERASE_TAIL_WAIT             = 6'd11,
                DRAW_HEAD                   = 6'd12,
                DRAW_HEAD_WAIT              = 6'd13,
                SHIFT_EXTEND                = 6'd14,
                SHIFT_EXTEND_WAIT           = 6'd15,
                LOAD_NEW_APPLE_COORD        = 6'd16,
                LOAD_NEW_APPLE_COORD_WAIT   = 6'd17,
                DRAW_APPLE                  = 6'd18,
                DRAW_APPLE_WAIT             = 6'd19,
                DRAW_HEAD2                  = 6'd20,
                DRAW_HEAD2_WAIT             = 6'd21,
                EXTEND                      = 6'd22,
                EXTEND_WAIT                 = 6'd23,
                DRAW_RED                    = 6'd24,
                DRAW_RED_WAIT               = 6'd25,
                WAIT_HALF_SEC1              = 6'd26,
                WAIT_HALF_SEC2              = 6'd27,
                WAIT_HALF_SEC3              = 6'd28,
                WAIT_HALF_SEC4              = 6'd29,
                DRAW_BLACK                  = 6'd30,
                DRAW_BLACK_WAIT             = 6'd31,
                RESET                       = 6'd32;
    
    // Next state logic aka our state table
    always@(*)
    begin: state_table 
            case (current_state)
                // Before game starts here
                BEFORE_GAME:                    next_state = space ?    DRAW_WHITE              : BEFORE_GAME;

                DRAW_WHITE:                     next_state = done ?     DRAW_WHITE_WAIT         : DRAW_WHITE;
                DRAW_WHITE_WAIT:                next_state = done ?     DRAW_WHITE_WAIT         : DRAW_SNAKE;

                DRAW_SNAKE:                     next_state = done ?     DRAW_SNAKE_WAIT         : DRAW_SNAKE;
                DRAW_SNAKE_WAIT:                next_state = done ?     DRAW_SNAKE_WAIT         : LOAD_FIRST_APPLE_COORD;

                LOAD_FIRST_APPLE_COORD:         next_state =            LOAD_FIRST_APPLE_COORD_WAIT;
                LOAD_FIRST_APPLE_COORD_WAIT:    next_state =            DRAW_FIRST_APPLE;

                DRAW_FIRST_APPLE:               next_state = done ?     DRAW_FIRST_APPLE_WAIT   : DRAW_FIRST_APPLE;
                DRAW_FIRST_APPLE_WAIT:          next_state = done ?     DRAW_FIRST_APPLE_WAIT   : WAIT_FOR_DECISION;

                WAIT_FOR_DECISION: begin
                    if (slow_clk) begin
                        if ( decision == 2'd0)     next_state =            ERASE_TAIL;
                        else if (decision == 2'd1) next_state =            DRAW_HEAD;
                        else if (decision == 2'd2) next_state =            LOAD_NEW_APPLE_COORD;
                        else                    next_state =            DRAW_RED;
                    end
                end

                // 00 Draw snake normal cycle starts here
                ERASE_TAIL:                     next_state = done ?     ERASE_TAIL_WAIT         : ERASE_TAIL;
                ERASE_TAIL_WAIT:                next_state = done ?     ERASE_TAIL_WAIT         : DRAW_HEAD;

                // 01 Draw snake with apple on tail starts here
                DRAW_HEAD:                      next_state = done ?     DRAW_HEAD_WAIT          : DRAW_HEAD;
                DRAW_HEAD_WAIT:                 next_state = done ?     DRAW_HEAD_WAIT          : SHIFT_EXTEND;

                SHIFT_EXTEND:                   next_state = done ?     SHIFT_EXTEND_WAIT       : SHIFT_EXTEND;
                SHIFT_EXTEND_WAIT:              next_state = done ?     SHIFT_EXTEND_WAIT       : WAIT_FOR_DECISION;

                // 10 Snake eats apple starts here
                LOAD_NEW_APPLE_COORD:           next_state =            LOAD_NEW_APPLE_COORD_WAIT;
                LOAD_NEW_APPLE_COORD_WAIT:      next_state =            DRAW_APPLE;

                DRAW_APPLE:                     next_state = done ?     DRAW_APPLE_WAIT         : DRAW_APPLE;
                DRAW_APPLE_WAIT:                next_state = done ?     DRAW_APPLE_WAIT         : DRAW_HEAD2;

                DRAW_HEAD2:                     next_state = done ?     DRAW_HEAD2_WAIT         : DRAW_HEAD2;
                DRAW_HEAD2_WAIT:                next_state = done ?     DRAW_HEAD2_WAIT         : EXTEND;

                EXTEND:                         next_state = done ?     EXTEND_WAIT             : EXTEND;
                EXTEND_WAIT:                    next_state = done ?     EXTEND_WAIT             : WAIT_FOR_DECISION;

                // 11 Snake dies starts here
                DRAW_RED:                       next_state = done ?     DRAW_RED_WAIT           : DRAW_RED;
                DRAW_RED_WAIT:                  next_state = done ?     DRAW_RED_WAIT           : WAIT_HALF_SEC1;

                WAIT_HALF_SEC1:                 next_state = slow_clk ? WAIT_HALF_SEC2          : WAIT_HALF_SEC1;
                WAIT_HALF_SEC2:                 next_state = slow_clk ? WAIT_HALF_SEC3          : WAIT_HALF_SEC2;
                WAIT_HALF_SEC3:                 next_state = slow_clk ? WAIT_HALF_SEC4          : WAIT_HALF_SEC3;
                WAIT_HALF_SEC4:                 next_state = slow_clk ? DRAW_BLACK              : WAIT_HALF_SEC4;

                DRAW_BLACK:                     next_state = done ?     DRAW_BLACK_WAIT         : DRAW_BLACK;
                DRAW_BLACK_WAIT:                next_state = done ?     DRAW_BLACK_WAIT         : RESET;

                RESET:                          next_state = BEFORE_GAME;
            default:     next_state = BEFORE_GAME;
        endcase
    end // state_table
   

    // Output logic aka all of our datapath control signals
    always @(*)
    begin: enable_signals
        // By default make all our signals 0

        draw_screen = 1'b0;
        draw_pixel_enable = 1'b0;
        load_apple_coord = 1'b0;
        shift_extend = 1'b0;
        extend = 1'b0;
        reset_all = 1'b0;
        colour = 3'b000;
        select_pixel_source = 2'b00; // 00 = head, 01 == tail, 10 == apple, 11 == body
        select_draw_source = 1'b0; // 0 = pixel, 1 = screen
        draw_body_signal = 1'b0;

        case (current_state)
            DRAW_WHITE: begin
                draw_screen = 1;
                select_draw_source = 1;
                colour = 3'b111;
            end
            DRAW_SNAKE: begin
                select_draw_source = 0;
                select_pixel_source = 2'b11;
                colour = 3'b001;
                draw_pixel_enable = 1;
                draw_body_signal = 1;
            end
            LOAD_FIRST_APPLE_COORD: begin
                load_apple_coord = 1;
            end
            DRAW_FIRST_APPLE: begin
                select_draw_source = 0;
                select_pixel_source = 2'b10;
                colour = 3'b100;
                draw_pixel_enable = 1;
            end
            ERASE_TAIL: begin
                select_draw_source = 0;
                select_pixel_source = 2'b01;
                colour = 3'b111;
                draw_pixel_enable = 1;
            end
            DRAW_HEAD: begin
                select_draw_source = 0;
                select_pixel_source = 2'b00;
                colour = 3'b001;
                draw_pixel_enable = 1;
            end
            SHIFT_EXTEND: begin
                shift_extend = 1;
            end
            LOAD_NEW_APPLE_COORD: begin
                load_apple_coord = 1;
            end
            DRAW_APPLE: begin
                select_draw_source = 0;
                select_pixel_source = 2'b10;
                colour = 3'b100;
                draw_pixel_enable = 1;
            end
            DRAW_HEAD2: begin
                select_draw_source = 0;
                select_pixel_source = 2'b00;
                colour = 3'b001;
                draw_pixel_enable = 1;
            end
            EXTEND: begin
                extend = 1;
            end
            DRAW_RED: begin
                draw_screen = 1;
                select_draw_source = 1;
                colour = 3'b100;
            end
            DRAW_BLACK: begin
                draw_screen = 1;
                select_draw_source = 1;
                colour = 3'b000;
            end
            RESET: begin
                reset_all = 1;
            end
        endcase
    end // enable_signals
     
    // current_state registers
    always@(posedge clk)
    begin: state_FFs
        if(!resetn)
            current_state <= BEFORE_GAME;
        else
            current_state <= next_state;
    end // state_FFS
endmodule

//TODO: figure out if the done signal is sent as a constant signal or a one tick pulse
module pseudoram(
    resetn, clk, slow_clk, shift_extend, extend, draw_body, pixel_done, new_headX, new_headY,
    bodyX, bodyY, draw_bodyX, draw_bodyY, draw_pixel_enable, headX, headY, tailX, tailY, body_done, shift_extend_done, extend_done, draw_body_done
);

    input resetn, clk, slow_clk, shift_extend, extend, draw_body, pixel_done;

    input [7:0] new_headX;
    input [6:0] new_headY;

    output reg [7:0] bodyX;
    output reg [6:0] bodyY;

    output reg [7:0] draw_bodyX;
    output reg [6:0] draw_bodyY;

    output reg body_done;
    output reg shift_extend_done;
    output reg extend_done;
    output reg draw_body_done;

    output reg draw_pixel_enable;

    output reg [7:0] headX;
    output reg [6:0] headY;

    output reg [7:0] tailX;
    output reg [6:0] tailY;

    reg [7:0] snakeX[0:127];
    reg [6:0] snakeY[0:127];

    reg enable;
    reg draw_enable;

    reg [4:0] head;

    reg [4:0] curr_index;
    reg [4:0] curr_index_draw;
    reg [1:0] shift_extend_step;
    reg [1:0] extend_step;

    integer i;
    integer j;
    always @(posedge clk) begin
        headX <= snakeX[head];
        headY <= snakeY[head];
        tailX <= snakeX[0];
        tailY <= snakeY[0];
        if (!resetn) begin
            enable <= 1'd0;
            head <= 5'd4;
            curr_index <= 5'd0;
            curr_index_draw <= 5'd0;
            bodyX <= 8'd0;
            bodyY <= 7'd0;

            draw_bodyX <= 8'd0;
            draw_bodyY <= 7'd0;

            body_done <= 0;
            shift_extend_done <= 0;
            extend_done <= 0;
            draw_body_done <= 0;

            draw_pixel_enable <= 0;
            draw_enable <= 0;

            shift_extend_step <= 2'd0;
            extend_step <= 2'd0;

            for(i=5;i<128;i=i+1) begin
                snakeX[i]=8'd0;
                snakeY[i]=7'd0;
            end
            snakeX[0]=8'd72;
            snakeX[1]=8'd74;
            snakeX[2]=8'd76;
            snakeX[3]=8'd78;
            snakeX[4]=8'd80;

            snakeY[0]=7'd60;
            snakeY[1]=7'd60;
            snakeY[2]=7'd60;
            snakeY[3]=7'd60;
            snakeY[4]=7'd60;
        end
        else begin
            // Begin the process of writing the snake body to bodyXY output
            if (slow_clk) begin
                enable <= 1;
            end
            // Output the body coords while curr_index has not reached the end
            if (enable && curr_index != (head + 5'd1)) begin
                bodyX <= snakeX[curr_index];
                bodyY <= snakeY[curr_index];
                curr_index <= curr_index + 5'd1;
            // If curr_index has reached the end, turn off enable and reset for next slow_clk cycle
            end else if (curr_index == (head + 5'd1)) begin
                enable <= 0;
                body_done <= 1;
                bodyX <= 8'd0;
                bodyY <= 7'd0;
                curr_index <= curr_index + 5'd1;
            end else if (curr_index == (head + 5'd2)) begin
                body_done <= 0;
                curr_index <= 5'd0;
            end else if (!enable) begin
                // If body writing above has finished and shift_extend signal received
                // begin shift_extend process by shifting each snake bit down
                if (shift_extend && shift_extend_step == 2'b00) begin
                    for(j=0;j<head;j=j+1) begin
                        snakeX[j] <= snakeX[j+1];
                        snakeY[j] <= snakeY[j+1];
                    end
                    shift_extend_step <= 2'b01;
                // Continue shift_extend by writing the new head
                end else if (shift_extend_step == 2'b01) begin
                    snakeX[head] <= new_headX;
                    snakeY[head] <= new_headY;
                    shift_extend_step <= 2'b10;
                // Signal shift_extend is finished
                end else if (shift_extend_step == 2'b10) begin
                    shift_extend_done <= 1;
                    shift_extend_step <= 2'b11;
                end else if (shift_extend_step == 2'b11) begin
                    shift_extend_done <= 0;
                    shift_extend_step <= 2'b00;

                // If extend signal received begin extend process by incrementing head
                end else if (extend && extend_step == 2'b00) begin
                    head <= head + 6'd1;
                    extend_step <= 2'b01;
                // Then set the new head
                end else if (extend_step == 2'b01) begin
                    snakeX[head] <= new_headX;
                    snakeY[head] <= new_headY;
                    extend_step <= 2'b10;
                // Then send done signal
                end else if (extend_step == 2'b10) begin
                    extend_done <= 1;
                    extend_step <= 2'b11;
                end else if (extend_step == 2'b11) begin
                    extend_done <= 0;
                    extend_step <= 2'b00;
                end else begin

                    // If draw_body signal is received begin draw_body process
                    if (draw_body) begin
                        draw_enable <= 1'b1; 
                    end
                    // If draw_body process has begun but pixel drawing isn't done yet
                    // output the curr_index coord to be drawn (the colour is handled by fsm)
                    if (draw_enable && curr_index_draw != (head + 5'd1) && !pixel_done) begin
                        draw_bodyX <= snakeX[curr_index_draw];
                        draw_bodyY <= snakeY[curr_index_draw];
                        draw_pixel_enable <= 1;
                    end
                    // If pixel_done signal is received increment to next snake bit
                    if (draw_enable && curr_index_draw != (head + 5'd1) && pixel_done) begin
                        curr_index_draw <= curr_index_draw + 5'd1;
                        draw_pixel_enable <= 0;
                    end
                    // If we've reached the end of the snake send the draw_body_done signal
                    if (curr_index_draw == (head + 5'd1)) begin
                        draw_body_done <= 1;
                        draw_bodyX <= 8'd0;
                        draw_bodyY <= 7'd0;
                        draw_enable <= 0;
                        curr_index_draw <= curr_index_draw + 5'd1;
                    end
                    if (curr_index_draw == (head + 5'd2)) begin
                        draw_body_done <= 0;
                        curr_index_draw <= 5'd0;
                    end
                end
            end
            //     extend_step <= 2'b01;
            // end else if (!enable && extend_step == 2'b01) begin
                
            //     extend_step <= 2'b10;
            // end else if (!enable && extend_step == 2'b10) begin
            //     extend_step <= 2'b00;
            // end
        end
    end

endmodule

module rate_divider(
    input clk,
    input resetn,
    output reg clk_out
);

    reg [24:0] counter;
    
    always @(posedge clk) begin
        if (!resetn) begin
            counter <= 25'd0;
            clk_out <= 1'b0;
        end
        else if (counter < 25'd25000000) begin
            counter <= counter + 25'd1;
            clk_out <= 1'b0;
        end
        else begin
            counter <= 25'd0;
            clk_out <= 1'b1;
        end
    end

endmodule

module new_head(
    input clk,
    input resetn,
    input [1:0] direction,
    input [7:0] head_x,
    input [6:0] head_y,
    output reg [7:0] new_head_x,
    output reg [6:0] new_head_y
);

    localparam UP = 2'd0;
    localparam RIGHT = 2'd1; 
    localparam DOWN = 2'd2;
    localparam LEFT = 2'd3;

    localparam SIZE = 2'd2;

    always @(posedge clk) begin
        if (!resetn) begin
            new_head_x <= 8'd0;
            new_head_y <= 7'd0;
        end
        else if (direction == UP) new_head_y <= head_y - SIZE;
        else if (direction == RIGHT) new_head_x <= head_x + SIZE;
        else if (direction == DOWN) new_head_y <= head_y + SIZE;
        else new_head_x <= head_x - SIZE;
    end

endmodule

module decision(
    input clk,
    input resetn,
    input [7:0] head_x,
    input [6:0] head_y,
    input [7:0] tail_x,
    input [6:0] tail_y,
    input [7:0] apple_x,
    input [6:0] apple_y,
    input [7:0] ram_x,
    input [6:0] ram_y,
    input ram_done,
    output reg [7:0] new_head_x,
    output reg [6:0] new_head_y,
    output reg [1:0] d
);

    localparam DRAW_NORMAL = 2'd0;
    localparam DRAW_NORMAL_APPLE_ON_TAIL = 2'd1;
    localparam DRAW_LEVEL_UP = 2'd2;
    localparam DRAW_GAME_OVER = 2'd3;

    localparam X_BOUNDARY = 8'd160;
    localparam Y_BOUNDARY = 7'd120;

    always @(posedge clk) begin
        if (!ram_done && head_x == ram_x && head_y == ram_y) d <= DRAW_GAME_OVER;
        else if (ram_done) begin
            if (head_x < 0 || head_x >= X_BOUNDARY || head_y < 0 || head_y >= Y_BOUNDARY)
                d <= DRAW_GAME_OVER;
            else if (head_x == apple_x && head_y == apple_y)
                d <= DRAW_LEVEL_UP;
            else if (tail_x == apple_x && tail_y == apple_y)
                d <= DRAW_NORMAL_APPLE_ON_TAIL;
            else
                d <= DRAW_NORMAL;
        end
        
        new_head_x <= head_x;
        new_head_y <= head_y;
    end

endmodule

module fill_screen(
    input clk,
    input resetn,
    input en,
    output reg [7:0] x,
    output reg [6:0] y,
    output reg writeEn,
    output reg done
);

    localparam X_BOUNDARY = 8'd160;
    localparam Y_BOUNDARY = 7'd120;
    
    reg [7:0] x_count;
    reg [6:0] y_count;

    always @(posedge clk) begin
        if (!resetn) begin
            x_count <= 8'd0;
            y_count <= 7'd0;
            x <= 8'd0;
            y <= 7'd0;
            writeEn <= 1'b0;
            done <= 1'b0;
        end
        else if (en) begin
            x <= x_count;
            y <= y_count;
            writeEn <= 1'b1;
            if (x_count < X_BOUNDARY) x_count <= x_count + 1;
            else if (x_count == X_BOUNDARY && y_count < Y_BOUNDARY) begin
                x_count <= 8'd0;
                y_count <= y_count + 1;
            end
            else begin
                writeEn <= 1'b0;
                done <= 1'b1;
            end
            if (done) begin
                done <= 1'b0;
                x_count <= 0;
                y_count <= 0;
            end
        end
    end
endmodule

module draw2by2(clk, x, y, reset, en, writeEn, done, x_out, y_out);
    input clk;
    input en;
    input reset;
    input [7:0] x;
    input [6:0] y;

    output reg [7:0] x_out;
    output reg [6:0] y_out;
    output reg done;

    output reg writeEn;

    reg [2:0] count;
    reg enable;

    always @(posedge clk) begin
        if (!reset) begin
            enable <= 1'd0;
            count <= 2'd0;
            x_out <= 8'd0;
            y_out <= 7'd0;
            done <= 1'd0;
            writeEn <= 1'b0;
        end
        else begin
            if (en && count == 0) begin
                enable <= 1'd1;
            end
            if (enable) begin
                x_out <= x + {6'd0, count[0]};
                y_out <= y + {5'd0, count[1]};
                count <= count + 3'd1;
                writeEn <= 1'b1;
            end
            if (count == 3) begin
                enable <= 1'd0;
                done <= 1'd1;
                count <= count + 3'd1;
            end
            if (count == 4) begin
                done <= 1'd0;
                writeEn <= 1'b0;
                count <= 3'd0;
            end
        end
    end
endmodule

module lsfr(
    input clk,
    input reset,
    input [6:0] seed,

    output [5:0] out
    );

    reg [5:0] val;
    
    always @ (posedge clk) begin
        if (!reset) begin
            val <= seed;
        end
        else begin
            val <= {val[2] ^ val[4], val[5:1]};
        end
    end

    assign out = val;
endmodule

module test2(
    input clk,
    input resetn,
    input w,
    input a,
    input s,
    input d,
    input space,
    output [7:0] x,
    output [6:0] y,
    output [2:0] colour,
    output writeEn);

    wire [1:0] dir;

    datapath d0(
        .direction(dir),
        .space(space),
        .clk(clk),
        .resetn(resetn),
        .x(x),
        .y(y),
        .colour(colour),
        .writeEn(writeEn)
    );
     
    // Control
    control c0(
        .clk(clk),
        .resetn(resetn),
        .w(w),
        .a(a),
        .s(s),
        .d(d),
        .direction(dir)
    );
endmodule

