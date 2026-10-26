alter table public.arcadots
    drop constraint if exists arcadots_active_game;

alter table public.arcadots
    add constraint arcadots_active_game check (
        active_game in ('sky-stack', 'pulse', 'orbit')
    );
