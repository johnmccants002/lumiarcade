create table if not exists public.arcadots (
    id text primary key,
    active_game text not null,
    updated_at timestamptz not null default now(),
    constraint arcadots_valid_id check (
        char_length(id) between 1 and 64
        and id ~ '^[A-Za-z0-9]+$'
    ),
    constraint arcadots_active_game check (
        active_game in ('sky-stack', 'pulse')
    )
);

alter table public.arcadots enable row level security;

revoke all on table public.arcadots from anon, authenticated;

comment on table public.arcadots is
    'Manually provisioned NFC Arcadots and the game each necklace currently launches.';
