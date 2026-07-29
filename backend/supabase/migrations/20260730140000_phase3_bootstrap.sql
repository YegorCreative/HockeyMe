alter table public.exercises
  add column if not exists slug text,
  add column if not exists instruction_steps text[] not null default '{}',
  add column if not exists coach_tips_list text[] not null default '{}',
  add column if not exists substitutions text[] not null default '{}';

create unique index if not exists exercises_slug_unique_idx
on public.exercises (slug)
where slug is not null;

create or replace function public.provision_coach(existing_user_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not exists (
    select 1
    from auth.users
    where id = existing_user_id
  ) then
    raise exception 'Auth user does not exist';
  end if;

  insert into public.coaches (user_id)
  values (existing_user_id)
  on conflict (user_id) do nothing;

  return found;
end;
$$;

revoke all on function public.provision_coach(uuid) from public;
revoke all on function public.provision_coach(uuid) from anon;
revoke all on function public.provision_coach(uuid) from authenticated;
grant execute on function public.provision_coach(uuid) to service_role;

insert into public.exercises (
  id,
  slug,
  name,
  category,
  hockey_category,
  primary_muscles,
  secondary_muscles,
  equipment,
  difficulty,
  video_url,
  instructions,
  instruction_steps,
  common_mistakes,
  coach_tips,
  coach_tips_list,
  substitution_notes,
  substitutions,
  is_active
)
values
(
  '10000000-0000-4000-8000-000000000001', 'back-squat',
  'Back Squat', 'Strength', 'Skating Strength',
  array['Quadriceps','Glutes'], array['Hamstrings','Core'],
  array['Barbell'], 'Intermediate',
  'https://videos.forgefitness.example/back-squat',
  'Sit between the hips while keeping the full foot connected to the floor.',
  array['Set up in a balanced athletic position.','Sit between the hips while keeping the full foot connected to the floor.','Finish every repetition with control and consistent technique.'],
  array['Letting the knees collapse inward.','Using more load or speed than can be controlled.'],
  'Sit between the hips while keeping the full foot connected to the floor.',
  array['Sit between the hips while keeping the full foot connected to the floor.','Stop the set when movement quality begins to change.'],
  'Front Squat; Goblet Squat', array['Front Squat','Goblet Squat'], true
),
(
  '10000000-0000-4000-8000-000000000002', 'front-squat',
  'Front Squat', 'Strength', 'Skating Strength',
  array['Quadriceps','Glutes'], array['Core','Upper Back'],
  array['Barbell'], 'Advanced',
  'https://videos.forgefitness.example/front-squat',
  'Keep the elbows high and torso stacked as you descend.',
  array['Set up in a balanced athletic position.','Keep the elbows high and torso stacked as you descend.','Finish every repetition with control and consistent technique.'],
  array['Losing the front-rack position.','Using more load or speed than can be controlled.'],
  'Keep the elbows high and torso stacked as you descend.',
  array['Keep the elbows high and torso stacked as you descend.','Stop the set when movement quality begins to change.'],
  'Back Squat; Goblet Squat', array['Back Squat','Goblet Squat'], true
),
(
  '10000000-0000-4000-8000-000000000003', 'trap-bar-deadlift',
  'Trap Bar Deadlift', 'Strength', 'Posterior Chain',
  array['Glutes','Hamstrings'], array['Quadriceps','Upper Back'],
  array['Trap Bar'], 'Intermediate',
  'https://videos.forgefitness.example/trap-bar-deadlift',
  'Push the rink away and finish tall without leaning back.',
  array['Set up in a balanced athletic position.','Push the rink away and finish tall without leaning back.','Finish every repetition with control and consistent technique.'],
  array['Jerking the bar from the floor.','Using more load or speed than can be controlled.'],
  'Push the rink away and finish tall without leaning back.',
  array['Push the rink away and finish tall without leaning back.','Stop the set when movement quality begins to change.'],
  'Barbell Deadlift; Dumbbell Romanian Deadlift', array['Barbell Deadlift','Dumbbell Romanian Deadlift'], true
),
(
  '10000000-0000-4000-8000-000000000004', 'bulgarian-split-squat',
  'Bulgarian Split Squat', 'Strength', 'Skating Strength',
  array['Quadriceps','Glutes'], array['Hamstrings','Adductors'],
  array['Dumbbells','Bench'], 'Intermediate',
  'https://videos.forgefitness.example/bulgarian-split-squat',
  'Load the front leg and keep the pelvis square.',
  array['Set up in a balanced athletic position.','Load the front leg and keep the pelvis square.','Finish every repetition with control and consistent technique.'],
  array['Pushing excessively from the rear foot.','Using more load or speed than can be controlled.'],
  'Load the front leg and keep the pelvis square.',
  array['Load the front leg and keep the pelvis square.','Stop the set when movement quality begins to change.'],
  'Reverse Lunge; Front-Foot Elevated Split Squat', array['Reverse Lunge','Front-Foot Elevated Split Squat'], true
),
(
  '10000000-0000-4000-8000-000000000005', 'nordic-hamstring-curl',
  'Nordic Hamstring Curl', 'Strength', 'Posterior Chain',
  array['Hamstrings'], array['Glutes','Calves'],
  array['Bodyweight'], 'Advanced',
  'https://videos.forgefitness.example/nordic-hamstring-curl',
  'Lower under control while keeping hips fully extended.',
  array['Set up in a balanced athletic position.','Lower under control while keeping hips fully extended.','Finish every repetition with control and consistent technique.'],
  array['Bending at the hips to shorten the range.','Using more load or speed than can be controlled.'],
  'Lower under control while keeping hips fully extended.',
  array['Lower under control while keeping hips fully extended.','Stop the set when movement quality begins to change.'],
  'Slider Leg Curl; Stability Ball Leg Curl', array['Slider Leg Curl','Stability Ball Leg Curl'], true
),
(
  '10000000-0000-4000-8000-000000000006', 'copenhagen-plank',
  'Copenhagen Plank', 'Core Stability', 'Groin Resilience',
  array['Adductors','Core'], array['Shoulders','Glutes'],
  array['Bench'], 'Advanced',
  'https://videos.forgefitness.example/copenhagen-plank',
  'Create a straight line from head to feet and drive the top leg down.',
  array['Set up in a balanced athletic position.','Create a straight line from head to feet and drive the top leg down.','Finish every repetition with control and consistent technique.'],
  array['Allowing the bottom hip to rotate toward the floor.','Using more load or speed than can be controlled.'],
  'Create a straight line from head to feet and drive the top leg down.',
  array['Create a straight line from head to feet and drive the top leg down.','Stop the set when movement quality begins to change.'],
  'Short-Lever Copenhagen Plank; Side Plank', array['Short-Lever Copenhagen Plank','Side Plank'], true
),
(
  '10000000-0000-4000-8000-000000000007', 'lateral-bounds',
  'Lateral Bounds', 'Plyometrics', 'Lateral Power',
  array['Glutes','Quadriceps'], array['Adductors','Calves'],
  array['Bodyweight'], 'Intermediate',
  'https://videos.forgefitness.example/lateral-bounds',
  'Project laterally and own each landing before the next bound.',
  array['Set up in a balanced athletic position.','Project laterally and own each landing before the next bound.','Finish every repetition with control and consistent technique.'],
  array['Rushing off an unstable landing.','Using more load or speed than can be controlled.'],
  'Project laterally and own each landing before the next bound.',
  array['Project laterally and own each landing before the next bound.','Stop the set when movement quality begins to change.'],
  'Skater Hops; Lateral Step-Up', array['Skater Hops','Lateral Step-Up'], true
),
(
  '10000000-0000-4000-8000-000000000008', 'box-jump',
  'Box Jump', 'Plyometrics', 'First-Step Quickness',
  array['Quadriceps','Glutes'], array['Hamstrings','Calves'],
  array['Plyo Box'], 'Intermediate',
  'https://videos.forgefitness.example/box-jump',
  'Jump explosively and land quietly in an athletic stance.',
  array['Set up in a balanced athletic position.','Jump explosively and land quietly in an athletic stance.','Finish every repetition with control and consistent technique.'],
  array['Choosing a box height that forces excessive knee tuck.','Using more load or speed than can be controlled.'],
  'Jump explosively and land quietly in an athletic stance.',
  array['Jump explosively and land quietly in an athletic stance.','Stop the set when movement quality begins to change.'],
  'Squat Jump; Broad Jump', array['Squat Jump','Broad Jump'], true
),
(
  '10000000-0000-4000-8000-000000000009', 'broad-jump',
  'Broad Jump', 'Plyometrics', 'First-Step Quickness',
  array['Glutes','Hamstrings'], array['Quadriceps','Calves'],
  array['Bodyweight'], 'Intermediate',
  'https://videos.forgefitness.example/broad-jump',
  'Project forward with a powerful arm swing and stick the landing.',
  array['Set up in a balanced athletic position.','Project forward with a powerful arm swing and stick the landing.','Finish every repetition with control and consistent technique.'],
  array['Landing with the chest falling forward.','Using more load or speed than can be controlled.'],
  'Project forward with a powerful arm swing and stick the landing.',
  array['Project forward with a powerful arm swing and stick the landing.','Stop the set when movement quality begins to change.'],
  'Box Jump; Countermovement Jump', array['Box Jump','Countermovement Jump'], true
),
(
  '10000000-0000-4000-8000-000000000010', 'skater-hops',
  'Skater Hops', 'Plyometrics', 'Lateral Power',
  array['Glutes','Quadriceps'], array['Adductors','Calves'],
  array['Bodyweight'], 'Beginner',
  'https://videos.forgefitness.example/skater-hops',
  'Stay low and move side to side with controlled single-leg contacts.',
  array['Set up in a balanced athletic position.','Stay low and move side to side with controlled single-leg contacts.','Finish every repetition with control and consistent technique.'],
  array['Standing upright between repetitions.','Using more load or speed than can be controlled.'],
  'Stay low and move side to side with controlled single-leg contacts.',
  array['Stay low and move side to side with controlled single-leg contacts.','Stop the set when movement quality begins to change.'],
  'Lateral Bounds; Lateral Line Hops', array['Lateral Bounds','Lateral Line Hops'], true
),
(
  '10000000-0000-4000-8000-000000000011', 'sled-push',
  'Sled Push', 'Conditioning', 'Work Capacity',
  array['Quadriceps','Glutes'], array['Calves','Core'],
  array['Sled'], 'Beginner',
  'https://videos.forgefitness.example/sled-push',
  'Maintain a strong forward angle and drive through complete steps.',
  array['Set up in a balanced athletic position.','Maintain a strong forward angle and drive through complete steps.','Finish every repetition with control and consistent technique.'],
  array['Taking short, choppy steps without full leg drive.','Using more load or speed than can be controlled.'],
  'Maintain a strong forward angle and drive through complete steps.',
  array['Maintain a strong forward angle and drive through complete steps.','Stop the set when movement quality begins to change.'],
  'Hill Sprint; Heavy Farmer Carry', array['Hill Sprint','Heavy Farmer Carry'], true
),
(
  '10000000-0000-4000-8000-000000000012', 'sled-pull',
  'Sled Pull', 'Conditioning', 'Posterior Chain',
  array['Hamstrings','Glutes'], array['Upper Back','Forearms'],
  array['Sled'], 'Intermediate',
  'https://videos.forgefitness.example/sled-pull',
  'Keep tension on the straps and walk with deliberate powerful steps.',
  array['Set up in a balanced athletic position.','Keep tension on the straps and walk with deliberate powerful steps.','Finish every repetition with control and consistent technique.'],
  array['Letting the lower back round under load.','Using more load or speed than can be controlled.'],
  'Keep tension on the straps and walk with deliberate powerful steps.',
  array['Keep tension on the straps and walk with deliberate powerful steps.','Stop the set when movement quality begins to change.'],
  'Backward Sled Drag; Cable Pull-Through', array['Backward Sled Drag','Cable Pull-Through'], true
),
(
  '10000000-0000-4000-8000-000000000013', 'chin-up',
  'Chin-Up', 'Strength', 'Upper-Body Strength',
  array['Lats','Biceps'], array['Upper Back','Forearms'],
  array['Pull-Up Bar'], 'Intermediate',
  'https://videos.forgefitness.example/chin-up',
  'Pull the chest toward the bar without losing trunk position.',
  array['Set up in a balanced athletic position.','Pull the chest toward the bar without losing trunk position.','Finish every repetition with control and consistent technique.'],
  array['Leading with the chin and overextending the neck.','Using more load or speed than can be controlled.'],
  'Pull the chest toward the bar without losing trunk position.',
  array['Pull the chest toward the bar without losing trunk position.','Stop the set when movement quality begins to change.'],
  'Band-Assisted Chin-Up; Lat Pulldown', array['Band-Assisted Chin-Up','Lat Pulldown'], true
),
(
  '10000000-0000-4000-8000-000000000014', 'pull-up',
  'Pull-Up', 'Strength', 'Upper-Body Strength',
  array['Lats','Upper Back'], array['Biceps','Forearms'],
  array['Pull-Up Bar'], 'Advanced',
  'https://videos.forgefitness.example/pull-up',
  'Begin from an active hang and drive elbows toward the ribs.',
  array['Set up in a balanced athletic position.','Begin from an active hang and drive elbows toward the ribs.','Finish every repetition with control and consistent technique.'],
  array['Swinging the legs to create momentum.','Using more load or speed than can be controlled.'],
  'Begin from an active hang and drive elbows toward the ribs.',
  array['Begin from an active hang and drive elbows toward the ribs.','Stop the set when movement quality begins to change.'],
  'Chin-Up; Band-Assisted Pull-Up', array['Chin-Up','Band-Assisted Pull-Up'], true
),
(
  '10000000-0000-4000-8000-000000000015', 'bench-press',
  'Bench Press', 'Strength', 'Upper-Body Strength',
  array['Chest','Triceps'], array['Shoulders'],
  array['Barbell','Bench'], 'Intermediate',
  'https://videos.forgefitness.example/bench-press',
  'Keep the upper back set and press from a stable base.',
  array['Set up in a balanced athletic position.','Keep the upper back set and press from a stable base.','Finish every repetition with control and consistent technique.'],
  array['Flaring the elbows directly out to the sides.','Using more load or speed than can be controlled.'],
  'Keep the upper back set and press from a stable base.',
  array['Keep the upper back set and press from a stable base.','Stop the set when movement quality begins to change.'],
  'Dumbbell Bench Press; Push-Up', array['Dumbbell Bench Press','Push-Up'], true
),
(
  '10000000-0000-4000-8000-000000000016', 'landmine-press',
  'Landmine Press', 'Strength', 'Upper-Body Strength',
  array['Shoulders','Triceps'], array['Chest','Core'],
  array['Landmine'], 'Beginner',
  'https://videos.forgefitness.example/landmine-press',
  'Press up and forward while keeping the ribs stacked over the pelvis.',
  array['Set up in a balanced athletic position.','Press up and forward while keeping the ribs stacked over the pelvis.','Finish every repetition with control and consistent technique.'],
  array['Rotating through the lower back to finish the press.','Using more load or speed than can be controlled.'],
  'Press up and forward while keeping the ribs stacked over the pelvis.',
  array['Press up and forward while keeping the ribs stacked over the pelvis.','Stop the set when movement quality begins to change.'],
  'Half-Kneeling Dumbbell Press; Incline Press', array['Half-Kneeling Dumbbell Press','Incline Press'], true
),
(
  '10000000-0000-4000-8000-000000000017', 'farmer-carry',
  'Farmer Carry', 'Strength', 'Work Capacity',
  array['Forearms','Core'], array['Upper Back','Glutes'],
  array['Dumbbells'], 'Beginner',
  'https://videos.forgefitness.example/farmer-carry',
  'Walk tall with quiet steps and keep the weights away from the thighs.',
  array['Set up in a balanced athletic position.','Walk tall with quiet steps and keep the weights away from the thighs.','Finish every repetition with control and consistent technique.'],
  array['Shrugging the shoulders and rushing the walk.','Using more load or speed than can be controlled.'],
  'Walk tall with quiet steps and keep the weights away from the thighs.',
  array['Walk tall with quiet steps and keep the weights away from the thighs.','Stop the set when movement quality begins to change.'],
  'Suitcase Carry; Trap Bar Carry', array['Suitcase Carry','Trap Bar Carry'], true
),
(
  '10000000-0000-4000-8000-000000000018', 'pallof-press',
  'Pallof Press', 'Core Stability', 'Trunk Control',
  array['Core'], array['Glutes','Shoulders'],
  array['Cable Machine'], 'Beginner',
  'https://videos.forgefitness.example/pallof-press',
  'Resist rotation as the hands move away from the chest.',
  array['Set up in a balanced athletic position.','Resist rotation as the hands move away from the chest.','Finish every repetition with control and consistent technique.'],
  array['Allowing the cable to turn the hips or shoulders.','Using more load or speed than can be controlled.'],
  'Resist rotation as the hands move away from the chest.',
  array['Resist rotation as the hands move away from the chest.','Stop the set when movement quality begins to change.'],
  'Tall-Kneeling Pallof Press; Dead Bug', array['Tall-Kneeling Pallof Press','Dead Bug'], true
)
on conflict (slug) where slug is not null do update
set
  name = excluded.name,
  category = excluded.category,
  hockey_category = excluded.hockey_category,
  primary_muscles = excluded.primary_muscles,
  secondary_muscles = excluded.secondary_muscles,
  equipment = excluded.equipment,
  difficulty = excluded.difficulty,
  video_url = excluded.video_url,
  instructions = excluded.instructions,
  instruction_steps = excluded.instruction_steps,
  common_mistakes = excluded.common_mistakes,
  coach_tips = excluded.coach_tips,
  coach_tips_list = excluded.coach_tips_list,
  substitution_notes = excluded.substitution_notes,
  substitutions = excluded.substitutions,
  is_active = excluded.is_active,
  updated_at = now();
