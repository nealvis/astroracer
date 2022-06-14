//////////////////////////////////////////////////////////////////////////////
// astro_ships_code.asm
// Copyright(c) 2021 Neal Smith.
// License: MIT. See LICENSE file in root directory.
//////////////////////////////////////////////////////////////////////////////

#importonce
#import "../nv_c64_util/nv_c64_util_macs_and_data.asm"

#import "astro_sprite_data.asm"
#import "../nv_c64_util/nv_sprite_extra_code.asm"
#import "astro_vars_data.asm"
#import "../nv_c64_util/nv_sprite_raw_collisions_code.asm"

// max and min speed for ships when inc/dec speed
.const SHIP_MAX_SPEED_16S = 5
.const SHIP_MIN_SPEED_16S = -5
.const SHIP_INC_VAL_16S = 1
.const SHIP_DEC_VAL_16S = -1
.const SHIP_MAX_SPEED_FP124S = NvBuildClosest124s(SHIP_MAX_SPEED_16S)
.const SHIP_MIN_SPEED_FP124S = NvBuildClosest124s(SHIP_MIN_SPEED_16S)
.const SHIP_INC_VAL_FP124S = NvBuildClosest124s(SHIP_INC_VAL_16S)
.const SHIP_DEC_VAL_FP124S = NvBuildClosest124s(SHIP_DEC_VAL_16S)
.const SHIP_MAX_SPEED_FOR_INC = NvBuildClosest124s(SHIP_MAX_SPEED_16S - SHIP_INC_VAL_16S)
.const SHIP_MIN_SPEED_FOR_DEC = NvBuildClosest124s(SHIP_MIN_SPEED_16S - (SHIP_DEC_VAL_16S))
//////////////////////////////////////////////////////////////////////////////
// namespace with everything related to ship sprite
.namespace ship_1
{
        .var info = nv_sprite_info_struct("ship_1", // sprite name 
                                          0,   // system sprite num
                                          NvBuildClosest124s(22),  // x loc
                                          NvBuildClosest124s(50),  // y loc
                                          NvBuildClosest124s(3),   // vel x
                                          NvBuildClosest124s(1),   // vel y 
                                          sprite_ship, 
                                          sprite_extra, 
                                          1,  // action top 
                                          0,  // action left 
                                          1,  // action bottom
                                          0,  // action right  
                                          NvBuildClosest124s(0),  // min top 
                                          NvBuildClosest124s(0),  // min left
                                          NvBuildClosest124s(75), // max bottom
                                          NvBuildClosest124s(0),  // max right
                                          0,  // sprite enabled 
                                          6,  // hitbox left
                                          4,  // hitbox top 
                                          19, // hitbox right
                                          16) // hitbox bottom

        .var sprite_num = info.num
        .label x_loc_fp124s = info.base_addr + NV_SPRITE_X_FP124S_OFFSET
        .label y_loc_fp124s = info.base_addr + NV_SPRITE_Y_FP124S_OFFSET
        .label x_vel_fp124s = info.base_addr + NV_SPRITE_VEL_X_FP124S_OFFSET
        .label y_vel_fp124s = info.base_addr + NV_SPRITE_VEL_Y_FP124S_OFFSET
        .label data_ptr = info.base_addr + NV_SPRITE_DATA_PTR_OFFSET
        .label base_addr = info.base_addr

// the extra data that goes with the sprite
sprite_extra:
        nv_sprite_extra_data(info)

// will be $FF (no collision) or sprite number of sprite colliding with
collision_sprite: .byte 0 

// score for this ship in BCD
score: .word 0

LoadExtraPtrToRegs:
    lda #>info.base_addr
    ldx #<info.base_addr
    rts

// subroutine to set the sprites location based on its address in extra block 
SetLocationFromExtraData:
        lda #>info.base_addr
        ldx #<info.base_addr
        jsr NvSpriteSetLocationFromExtra
        rts

// subroutine to setup the sprite so that its ready to be enabled and displayed
Setup:
        lda #>info.base_addr
        ldx #<info.base_addr
.break
        jsr NvSpriteSetupFromExtra
        rts

// subroutine to move the sprite in memory only (the extra data)
// this will not update the sprite registers to actually move the sprite, but
// to do that just call SetShipeLocFromMem
MoveInExtraData:
        lda #>info.base_addr
        ldx #<info.base_addr
        jsr NvSpriteMoveInExtra
        rts
        //nv_sprite_move_any_direction_sr(info)

Enable:
        lda #>info.base_addr
        ldx #<info.base_addr
        nv_sprite_extra_enable_sr()

Disable:
        lda #>info.base_addr
        ldx #<info.base_addr
        nv_sprite_extra_disable_sr()

// Accum must have MSB of new data_ptr
// X Reg must have LSB of new data_ptr
SetDataPtr:
{
    stx data_ptr
    sta data_ptr+1

    //   Accum: MSB of address of nv_sprite_extra_data
    //   X Reg: LSB of address of the nv_sprite_extra_data
    lda #>info.base_addr
    ldx #<info.base_addr
    jsr NvSpriteSetDataPtrFromExtra
    rts
}

LoadEnabledToA:
        lda info.base_addr + NV_SPRITE_ENABLED_OFFSET
        rts

SetBounceAllOn:
        nv_sprite_set_all_actions_sr(info, NV_SPRITE_ACTION_BOUNCE)

SetWrapAllOn:
        nv_sprite_set_all_actions_sr(info, NV_SPRITE_ACTION_WRAP)

//////////////////////////////////////////////////////////////////////////////
// subroutine to check for collisions with the ship (sprite 0)
CheckShipCollision:
    lda sprite_collision_reg_value
    //nv_debug_print_labeled_byte_mem(0, 0, temp_label, 10, sprite_collision_reg_value, true, false)
    sta nv_a8
    nv_sprite_raw_check_collision(info.num)
    lda nv_b8
    sta ship_1.collision_sprite
    //jsr DebugShipCollisionSprite
    rts
temp_label: .text @"coll reg: \$00"

DecVelX:
{
    nv_blt124s_immed_far(nv_sprite_vel_x_fp124s_addr(info), SHIP_MIN_SPEED_FOR_DEC, DoneDecVelX)
    nv_adc124s(nv_sprite_vel_x_fp124s_addr(info), DecValFp124s, nv_sprite_vel_x_fp124s_addr(info), temp1, temp2, false)
DoneDecVelX:
    rts
DecValFp124s: .word SHIP_DEC_VAL_FP124S
temp1: .word $0000
temp2: .word $0000
}


IncVelX:
{
    nv_bgt124s_immed_far(nv_sprite_vel_x_fp124s_addr(info), SHIP_MAX_SPEED_FOR_INC, DoneIncVelX)
    nv_adc124s(nv_sprite_vel_x_fp124s_addr(info), IncValFp124s, nv_sprite_vel_x_fp124s_addr(info), temp1, temp2, false)
DoneIncVelX:
    rts
IncValFp124s: .word SHIP_INC_VAL_FP124S
temp1: .word $0000
temp2: .word $0000
}

//////////////////////////////////////////////////////////////////////////////
// x and y reg have x and y screen loc for the char to check the sprite 
// location against.  it doesn't matter what character is at the location
// this just checks the location for overlap with sprite location
CheckOverlapChar:
    nv_sprite_check_overlap_char(info, rect2)
    rts

SetColorDead:
    nv_sprite_set_raw_color_immed(sprite_num, NV_COLOR_GREY)
    rts

SetColorAlive:
    lda #>info.base_addr
    ldx #<info.base_addr
    nv_sprite_set_color_from_extra_sr()

    
label_vel_x_str: .text @"vel x: \$00"
rect1: .word $0000, $0000  // (left, top)
       .word $0000, $0000  // (right, bottom)

rect2: .word $0000, $0000  // (left, top)
       .word $0000, $0000  // (right, bottom)

}

//////////////////////////////////////////////////////////////////////////////
// namespace with everything related to ship sprite
.namespace ship_2
{
    .var info = nv_sprite_info_struct("ship_2", // sprite name
                                      7,   // system sprite num
                                      NvBuildClosest124s(22),  // x loc
                                      NvBuildClosest124s(210), // y loc
                                      NvBuildClosest124s(3),   // vel x
                                      NvBuildClosest124s(1),   // vel y 
                                      sprite_ship, 
                                      sprite_extra, 
                                      1, // action top 
                                      0, // action left
                                      1, // action bottom
                                      0, // action right  
                                      NvBuildClosest124s(200), // min top
                                      NvBuildClosest124s(0),   // min left
                                      NvBuildClosest124s(0),   // max bottom
                                      NvBuildClosest124s(0),   // max right
                                      0,            // sprite enabled 
                                      6,  // hitbox left
                                      4,  // hitbox top
                                      19, // hitbox right
                                      16) // hitbox bottom

    .var sprite_num = info.num
    .label x_loc_fp124s = info.base_addr + NV_SPRITE_X_FP124S_OFFSET
    .label y_loc_fp124s = info.base_addr + NV_SPRITE_Y_FP124S_OFFSET
    .label x_vel_fp124s = info.base_addr + NV_SPRITE_VEL_X_FP124S_OFFSET
    .label y_vel_fp124s = info.base_addr + NV_SPRITE_VEL_Y_FP124S_OFFSET
    .label data_ptr = info.base_addr + NV_SPRITE_DATA_PTR_OFFSET
    .label base_addr = info.base_addr
    .label sprite_extra_addr = info.base_addr

// the extra data that goes with the sprite
sprite_extra:
        nv_sprite_extra_data(info)



// will be $FF (no collision) or sprite number of sprite colliding with
collision_sprite: .byte 0

// score for this ship in BCD
score: .word 0

LoadExtraPtrToRegs:
    lda #>info.base_addr
    ldx #<info.base_addr
    rts


// subroutine to set the sprites location based on its address in extra block 
SetLocationFromExtraData:
        lda #>info.base_addr
        ldx #<info.base_addr
        jsr NvSpriteSetLocationFromExtra
        rts

// subroutine to setup the sprite so that its ready to be enabled and displayed
Setup:
        lda #>info.base_addr
        ldx #<info.base_addr
        jsr NvSpriteSetupFromExtra
        rts

// subroutine to move the sprite in memory only (the extra data)
// this will not update the sprite registers to actually move the sprite, but
// to do that just call SetShipeLocFromMem
MoveInExtraData:
        lda #>info.base_addr
        ldx #<info.base_addr
        jsr NvSpriteMoveInExtra
        rts
        //nv_sprite_move_any_direction_sr(info)

Enable:
        lda #>info.base_addr
        ldx #<info.base_addr
        nv_sprite_extra_enable_sr()

Disable:
        lda #>info.base_addr
        ldx #<info.base_addr
        nv_sprite_extra_disable_sr()

// Accum must have MSB of new data_ptr
// X Reg must have LSB of new data_ptr
SetDataPtr:
{
    stx data_ptr
    sta data_ptr+1

    //   Accum: MSB of address of nv_sprite_extra_data
    //   X Reg: LSB of address of the nv_sprite_extra_data
    lda #>info.base_addr
    ldx #<info.base_addr
    jsr NvSpriteSetDataPtrFromExtra
    rts
}

LoadEnabledToA:
        lda info.base_addr + NV_SPRITE_ENABLED_OFFSET
        rts

SetBounceAllOn:
        nv_sprite_set_all_actions_sr(info, NV_SPRITE_ACTION_BOUNCE)

SetWrapAllOn:
        nv_sprite_set_all_actions_sr(info, NV_SPRITE_ACTION_WRAP)

//////////////////////////////////////////////////////////////////////////////
// subroutine to check for collisions with the ship (sprite 0)
CheckShipCollision:
    lda sprite_collision_reg_value
    //nv_debug_print_labeled_byte_mem(0, 0, temp_label, 10, sprite_collision_reg_value, true, false)
    sta nv_a8
    nv_sprite_raw_check_collision(info.num)
    lda nv_b8
    sta ship_2.collision_sprite
    rts


DecVelX:
{
    nv_blt124s_immed_far(nv_sprite_vel_x_fp124s_addr(info), SHIP_MIN_SPEED_FOR_DEC, DoneDecVelX)
    nv_adc124s(nv_sprite_vel_x_fp124s_addr(info), DecValFp124s, nv_sprite_vel_x_fp124s_addr(info), temp1, temp2, false)
DoneDecVelX:
    rts
DecValFp124s: .word SHIP_DEC_VAL_FP124S
temp1: .word $0000
temp2: .word $0000
}


IncVelX:
{
    nv_bgt124s_immed_far(nv_sprite_vel_x_fp124s_addr(info), SHIP_MAX_SPEED_FOR_INC, DoneIncVelX)
    nv_adc124s(nv_sprite_vel_x_fp124s_addr(info), IncValFp124s, nv_sprite_vel_x_fp124s_addr(info), temp1, temp2, false)
DoneIncVelX:
    rts
IncValFp124s: .word SHIP_INC_VAL_FP124S
temp1: .word $0000
temp2: .word $0000
}


SetColorDead:
    nv_sprite_set_raw_color_immed(sprite_num, NV_COLOR_GREY)
    rts

SetColorAlive:
    //lda #>info.base_addr
    //ldx #<info.base_addr
    //nv_sprite_set_color_from_extra_sr()
    nv_sprite_set_raw_color_immed(sprite_num, NV_COLOR_BROWN)
    rts



label_vel_x_str: .text @"vel x: \$00"

}