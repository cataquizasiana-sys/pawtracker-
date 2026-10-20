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
