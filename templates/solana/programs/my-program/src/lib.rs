use anchor_lang::prelude::*;

declare_id!("HhXfJEHUyDGYBSD9uJh6pZYEYoBY6ysd7yG8TrYJuKEV");

#[program]
pub mod my_program {
    use super::*;

    pub fn initialize(ctx: Context<Initialize>) -> Result<()> {
        msg!("Greetings from: {:?}", ctx.program_id);
        Ok(())
    }
}

#[derive(Accounts)]
pub struct Initialize {}
