-- Run this in Supabase SQL Editor. Never put the service-role key in frontend code.
create extension if not exists pgcrypto;

create table if not exists public.pets (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  pet_name text not null check (char_length(pet_name) between 1 and 80),
  species text not null check (species in ('Dog','Cat','Other')),
  breed text check (breed is null or char_length(breed) <= 100),
  age numeric(4,1) check (age is null or age between 0 and 40),
  sex text check (sex is null or sex in ('Female','Male')),
  identifier text check (identifier is null or char_length(identifier) <= 120),
  photo_url text,
  contact_name text not null check (char_length(contact_name) between 1 and 100),
  contact_phone text check (contact_phone is null or char_length(contact_phone) <= 30),
  emergency_phone text check (emergency_phone is null or char_length(emergency_phone) <= 30),
  public_email text check (public_email is null or char_length(public_email) <= 254),
  care_notes text check (care_notes is null or char_length(care_notes) <= 1000),
  medical_conditions text check (medical_conditions is null or char_length(medical_conditions) <= 500),
  allergies text check (allergies is null or char_length(allergies) <= 500),
  medications text check (medications is null or char_length(medications) <= 500),
  vaccination_notes text check (vaccination_notes is null or char_length(vaccination_notes) <= 500),
  vet_name text check (vet_name is null or char_length(vet_name) <= 150),
  vet_phone text check (vet_phone is null or char_length(vet_phone) <= 30),
  temperament text check (temperament is null or char_length(temperament) <= 500),
  visibility text not null default 'public' check (visibility in ('public','private')),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
-- Add these columns when upgrading an existing PawTracker database.
alter table public.pets add column if not exists medical_conditions text check (medical_conditions is null or char_length(medical_conditions) <= 500);
alter table public.pets add column if not exists allergies text check (allergies is null or char_length(allergies) <= 500);
alter table public.pets add column if not exists medications text check (medications is null or char_length(medications) <= 500);
alter table public.pets add column if not exists vaccination_notes text check (vaccination_notes is null or char_length(vaccination_notes) <= 500);
alter table public.pets add column if not exists vet_name text check (vet_name is null or char_length(vet_name) <= 150);
alter table public.pets add column if not exists vet_phone text check (vet_phone is null or char_length(vet_phone) <= 30);

create index if not exists pets_owner_id_idx on public.pets(owner_id);
create index if not exists pets_public_idx on public.pets(id) where is_active = true and visibility = 'public';

alter table public.pets enable row level security;
drop policy if exists "Owners can view their own pets" on public.pets;
create policy "Owners can view their own pets" on public.pets for select to authenticated using (auth.uid() = owner_id);
drop policy if exists "Public can view active public pet profiles" on public.pets;
-- Public visitors must use the limited-column view below, never the base table.
drop policy if exists "Owners can view their own pets" on public.pets;
create policy "Owners can view their own pets" on public.pets for select to authenticated using (auth.uid() = owner_id);

-- The QR profile exposes only approved public fields. Emergency contact and owner_id
-- are intentionally excluded. The view filters private/deactivated profiles server-side.
drop view if exists public.public_pet_profiles;
create view public.public_pet_profiles with (security_invoker = false) as
select id, pet_name, species, breed, age, sex, identifier, photo_url,
       contact_name, contact_phone, public_email, care_notes, medical_conditions, allergies, medications, vaccination_notes, vet_name, vet_phone, temperament,
       visibility, is_active
from public.pets
where is_active = true and visibility = 'public';
revoke all on public.pets from anon;
grant select, insert, update, delete on public.pets to authenticated;
revoke all on public.public_pet_profiles from public;
grant select on public.public_pet_profiles to anon, authenticated;
drop policy if exists "Owners can insert their own pets" on public.pets;
create policy "Owners can insert their own pets" on public.pets for insert to authenticated with check (auth.uid() = owner_id);
drop policy if exists "Owners can update their own pets" on public.pets;
create policy "Owners can update their own pets" on public.pets for update to authenticated using (auth.uid() = owner_id) with check (auth.uid() = owner_id);
drop policy if exists "Owners can delete their own pets" on public.pets;
create policy "Owners can delete their own pets" on public.pets for delete to authenticated using (auth.uid() = owner_id);

create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end;
$$;
drop trigger if exists pets_updated_at on public.pets;
create trigger pets_updated_at before update on public.pets for each row execute function public.set_updated_at();

-- Create a Storage bucket named pet-photos in Supabase Storage and set it to public
-- only if public photos are intended. Use these policies for owner-managed uploads:
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('pet-photos','pet-photos',true,5242880,array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set file_size_limit=5242880, allowed_mime_types=array['image/jpeg','image/png','image/webp'];
drop policy if exists "Owners upload pet photos to own folder" on storage.objects;
create policy "Owners upload pet photos to own folder" on storage.objects for insert to authenticated with check (bucket_id='pet-photos' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "Owners update pet photos in own folder" on storage.objects;
create policy "Owners update pet photos in own folder" on storage.objects for update to authenticated using (bucket_id='pet-photos' and (storage.foldername(name))[1] = auth.uid()::text) with check (bucket_id='pet-photos' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "Owners delete pet photos in own folder" on storage.objects;
create policy "Owners delete pet photos in own folder" on storage.objects for delete to authenticated using (bucket_id='pet-photos' and (storage.foldername(name))[1] = auth.uid()::text);

-- PawTracker medical profile fields (safe to run on an existing project).
alter table public.pets add column if not exists medical_conditions text check (medical_conditions is null or char_length(medical_conditions) <= 500);
alter table public.pets add column if not exists allergies text check (allergies is null or char_length(allergies) <= 500);
alter table public.pets add column if not exists medications text check (medications is null or char_length(medications) <= 500);
alter table public.pets add column if not exists vaccination_notes text check (vaccination_notes is null or char_length(vaccination_notes) <= 500);
alter table public.pets add column if not exists vet_name text check (vet_name is null or char_length(vet_name) <= 150);
alter table public.pets add column if not exists vet_phone text check (vet_phone is null or char_length(vet_phone) <= 30);
drop view if exists public.public_pet_profiles;
create view public.public_pet_profiles with (security_invoker = false) as
select id, pet_name, species, breed, age, sex, identifier, photo_url,
       contact_name, contact_phone, public_email, care_notes, medical_conditions, allergies, medications, vaccination_notes, vet_name, vet_phone, temperament,
       visibility, is_active
from public.pets where is_active = true and visibility = 'public';
revoke all on public.public_pet_profiles from public;
grant select on public.public_pet_profiles to anon, authenticated;
