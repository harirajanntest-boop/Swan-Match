/**
 * Swan Match — Create 50 Test Users (25 Male + 25 Female)
 *
 * Run from the functions/ directory:
 *   cd functions && node ../scripts/create_test_users.js
 *
 * All test user doc IDs start with "test_male_" or "test_female_"
 * so they can be bulk-deleted easily with delete_test_users.js
 */

const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp({ projectId: 'swan-match' });
}
const db = admin.firestore();
const FieldValue = admin.firestore.FieldValue;

// ─── Data pools ──────────────────────────────────────────────────────────────

const maleFirstNames = [
  'Arjun','Vikram','Rohan','Aditya','Karthik','Nikhil','Siddharth','Rahul',
  'Aryan','Dev','Ishaan','Kabir','Manav','Neel','Omkar','Pranav','Reyansh',
  'Samar','Taran','Utkarsh','Varun','Yash','Zain','Aarav','Dhruv'
];
const femaleFirstNames = [
  'Ananya','Priya','Meera','Ishita','Kavya','Nisha','Riya','Sneha',
  'Tanvi','Aisha','Diya','Eesha','Gauri','Hira','Ira','Janvi','Kiara',
  'Lavanya','Myra','Neha','Oviya','Pooja','Radhika','Saanvi','Tanya'
];
const lastNames = [
  'Sharma','Patel','Reddy','Kumar','Singh','Nair','Iyer','Desai',
  'Gupta','Mehta','Joshi','Rao','Pillai','Bhat','Kapoor','Malhotra',
  'Chopra','Khanna','Verma','Saxena','Mishra','Pandey','Shah','Das','Banerjee'
];

const cities = [
  'Mumbai','Delhi','Bangalore','Chennai','Hyderabad','Pune','Kolkata',
  'Ahmedabad','Jaipur','Lucknow','Kochi','Chandigarh','Indore','Coimbatore',
  'Goa','Mysore','Vadodara','Surat','Nagpur','Bhopal','Thiruvananthapuram',
  'Vizag','Mangalore','Udaipur','Noida'
];
const countries = ['India'];

const religions = ['Hindu','Muslim','Christian','Sikh','Jain','Buddhist','Spiritual'];
const ethnicities = ['South Asian','South Indian','North Indian','East Indian','West Indian'];
const professions = [
  'Software Engineer','Doctor','Lawyer','Architect','Data Scientist',
  'Product Manager','Investment Banker','Marketing Manager','Civil Engineer',
  'Teacher','Chartered Accountant','Entrepreneur','UX Designer',
  'Mechanical Engineer','Journalist','Pharmacist','Dentist','Pilot',
  'Management Consultant','Research Scientist','Content Creator',
  'Fashion Designer','Graphic Designer','HR Manager','Business Analyst'
];
const educationLevels = ['Bachelor','Master','Doctorate','Associate Degree','MBA'];
const industries = ['IT','Finance','Healthcare','Education','Engineering','Media','Legal','Consulting'];
const incomeRanges = ['25K - 50K','50K - 100K','100K - 200K','200K+'];
const lookingForOptions = ['Marriage','Long-term Relationship'];
const maritalStatuses = ['Never Married','Divorced','Widowed'];
const smokingOptions = ['Never','Occasionally','Socially'];
const drinkingOptions = ['Never','Occasionally','Socially'];
const personalityTraitPool = [
  'Ambitious','Creative','Empathetic','Adventurous','Intellectual',
  'Humorous','Confident','Calm','Optimistic','Passionate',
  'Loyal','Independent','Caring','Spontaneous','Thoughtful'
];
const interestPool = [
  'Travel','Photography','Cooking','Reading','Fitness','Music','Movies',
  'Hiking','Yoga','Dancing','Art','Technology','Gaming','Meditation',
  'Writing','Gardening','Swimming','Cycling','Cricket','Badminton',
  'Tennis','Chess','Volunteering','Astronomy','Entrepreneurship'
];
const lifestyleTagPool = ['Health-focused','Career-driven','Family-oriented','Social','Adventure-seeking','Luxury'];
const languagePool = ['Hindi','English','Tamil','Telugu','Kannada','Malayalam','Bengali','Marathi','Gujarati','Punjabi'];

const maleBios = [
  "Passionate about building things that matter. Love exploring new cuisines and weekend road trips.",
  "Finance professional by day, amateur chef by night. Looking for someone who appreciates both spreadsheets and soufflés.",
  "Tech enthusiast who believes in work-life balance. Mountain trails on weekends, code during the week.",
  "Avid reader with a love for jazz music. Seeking a meaningful connection built on mutual respect and shared laughter.",
  "Entrepreneur at heart, always chasing the next big idea. Love meaningful conversations over great coffee.",
  "Sports fanatic and fitness enthusiast. Believe that a healthy body leads to a healthy mind and relationship.",
  "Architect who finds beauty in both structures and sunsets. Looking for my forever travel companion.",
  "Music producer with a soul for poetry. Every love story deserves a great soundtrack.",
  "Environmental scientist passionate about sustainability. Let's build a greener future together.",
  "Data scientist who believes numbers tell stories. My favorite story? Still being written.",
  "Medical professional dedicated to healing. Looking for someone who values compassion and kindness.",
  "Pilot who's seen the world from above. Ready to explore it on the ground with the right person.",
  "Photographer capturing moments one frame at a time. Seeking someone to be in the picture.",
  "Startup founder balancing chaos and creativity. Need a partner who thrives in both.",
  "Classical musician with modern dreams. Harmony in music, harmony in life.",
  "Investment banker who trades stocks by day and stories by night. Looking for my best chapter.",
  "Civil engineer building bridges — literally and figuratively. Let's connect.",
  "Research scientist exploring the unknown. The greatest discovery? A genuine connection.",
  "Marketing strategist who writes better love letters than ad copy. Prove me wrong.",
  "Teacher who believes education changes the world. Looking for a lifelong learning partner.",
  "Mechanical engineer with a creative side. I fix machines and broken playlists.",
  "Lawyer who argues for a living but prefers peace at home. Let's build something meaningful.",
  "Journalist chasing truth and sunsets. Looking for someone who values honesty.",
  "Management consultant optimizing life, one decision at a time. The best decision? Still pending.",
  "Content creator telling stories that matter. The next story could be ours."
];

const femaleBios = [
  "Creative soul with a passion for design and travel. Believe every journey is better shared.",
  "Doctor who heals by day and paints by night. Looking for someone who appreciates both science and art.",
  "Bookworm with wanderlust. My ideal date involves a cozy café, great conversation, and zero phone screens.",
  "Marketing professional with a love for storytelling. Searching for my favorite plot twist.",
  "Yoga instructor finding balance in chaos. Looking for a partner who values inner peace.",
  "Fashion designer crafting dreams into reality. Need someone who appreciates the details.",
  "Software engineer breaking stereotypes and bugs. Looking for someone who values ambition and authenticity.",
  "Food blogger who believes the way to the heart is through the stomach. Let me prove it.",
  "Environmental activist passionate about making a difference. Seeking a like-minded soul.",
  "Classical dancer who finds expression in movement. Looking for someone who moves to the same rhythm.",
  "Architect designing spaces that inspire. My next project? Building a beautiful life together.",
  "Chartered accountant who balances books and life equally well. Seeking genuine connection.",
  "HR professional who understands people. Still looking for the one person who understands me.",
  "Graphic designer coloring outside the lines. Looking for someone who appreciates creativity.",
  "Research scientist exploring possibilities. The biggest experiment? Finding the right match.",
  "Startup founder turning vision into reality. Need a co-pilot for this adventure called life.",
  "Teacher shaping minds and futures. Looking for a partner who values education and growth.",
  "Musician composing melodies and memories. The best song? A duet.",
  "Fitness enthusiast who runs marathons and conversations. Looking for a running partner for life.",
  "Photographer capturing emotions in every frame. Seeking the subject of my masterpiece.",
  "Lawyer fighting for justice and Friday night pizza. Looking for someone to share both.",
  "Data analyst finding patterns everywhere except in love. Can you be the exception?",
  "Interior designer creating beautiful spaces. Looking for someone to share my beautiful space.",
  "Content writer crafting stories that resonate. The next love story could be mine.",
  "Pharmacist dispensing health and happiness. Looking for my daily dose of laughter."
];

// ─── Helpers ─────────────────────────────────────────────────────────────────

function pick(arr) { return arr[Math.floor(Math.random() * arr.length)]; }
function pickN(arr, n) {
  const shuffled = [...arr].sort(() => 0.5 - Math.random());
  return shuffled.slice(0, Math.min(n, shuffled.length));
}
function randomAge(min = 22, max = 38) { return min + Math.floor(Math.random() * (max - min + 1)); }
function randomDOB(age) {
  const year = new Date().getFullYear() - age;
  const month = Math.floor(Math.random() * 12);
  const day = 1 + Math.floor(Math.random() * 28);
  return new Date(year, month, day);
}

/**
 * Generate 3 unique photo URLs per user using picsum.photos (stable, free stock photos).
 * Each photo gets a unique seed so every user has different images.
 */
function generatePhotos(userId, gender) {
  // Use unique seeds per user for consistent but different photos
  const photos = [];
  for (let i = 0; i < 3; i++) {
    // picsum.photos with seed gives a stable, unique image per seed
    photos.push(`https://picsum.photos/seed/${userId}_${i}/600/800`);
  }
  return photos;
}

// ─── Build user document ─────────────────────────────────────────────────────

function buildUser(index, gender) {
  const isMale = gender === 'Male';
  const prefix = isMale ? 'test_male' : 'test_female';
  const docId = `${prefix}_${String(index).padStart(2, '0')}`;

  const firstName = isMale ? maleFirstNames[index] : femaleFirstNames[index];
  const lastName = lastNames[index];
  const age = randomAge();
  const dob = randomDOB(age);
  const city = cities[index];
  const bio = isMale ? maleBios[index] : femaleBios[index];
  const photos = generatePhotos(docId, gender);

  return {
    docId,
    data: {
      uid: docId,
      name: `${firstName} ${lastName}`,
      firstName,
      lastName,
      email: `${docId}@test.swanmatch.com`,
      phoneNumber: '',
      gender,
      showGender: true,
      dateOfBirth: admin.firestore.Timestamp.fromDate(dob),
      bio,
      photos,
      images: photos,
      profilePicture: photos[0],
      interests: pickN(interestPool, 4 + Math.floor(Math.random() * 4)),
      location: `${city}, India`,
      city,
      state: '',
      country: 'India',
      age,
      subscriptionPlan: 'free',
      profileVerified: false,
      isVerified: false,
      verificationStatus: '',
      verificationPhotoUrl: '',
      registrationCompleted: true,
      partnerPreference: '',
      minAgePreference: Math.max(18, age - 5),
      maxAgePreference: age + 5,
      distanceKm: 50,
      lookingFor: pick(lookingForOptions),
      highestQualification: pick(educationLevels),
      university: '',
      profession: professions[index],
      drinking: pick(drinkingOptions),
      smoking: pick(smokingOptions),
      workout: pick(['Never', 'Sometimes', 'Often', 'Daily']),
      pets: [],
      communicationStyle: pick(['Texting', 'Calling', 'In-person', 'Video calls']),
      loveLanguage: pick(['Words of Affirmation', 'Quality Time', 'Acts of Service', 'Physical Touch', 'Gifts']),
      educationLevel: pick(educationLevels),
      zodiac: pick(['Aries','Taurus','Gemini','Cancer','Leo','Virgo','Libra','Scorpio','Sagittarius','Capricorn','Aquarius','Pisces']),

      // Premium onboarding fields
      maritalStatus: pick(maritalStatuses),
      hasChildren: false,
      childrenDetails: '',
      willingToRelocate: Math.random() > 0.5,
      industry: pick(industries),
      incomeRange: pick(incomeRanges),
      netWorthRange: '',
      lifestyleTags: pickN(lifestyleTagPool, 2 + Math.floor(Math.random() * 3)),
      religion: pick(religions),
      spiritualLevel: pick(['Not Religious', 'Somewhat', 'Very', 'Deeply']),
      ethnicity: pick(ethnicities),
      primaryLanguage: pick(['English', 'Hindi', 'Tamil', 'Telugu']),
      otherLanguages: pickN(languagePool, 1 + Math.floor(Math.random() * 2)),
      languageFluency: {},
      familyValuesImportance: 2 + Math.floor(Math.random() * 4),
      personalityTraits: pickN(personalityTraitPool, 3 + Math.floor(Math.random() * 3)),
      preferredLocation: pick(cities),
      preferredEducation: pick(educationLevels),
      preferredProfession: '',
      preferredLifestyle: pickN(lifestyleTagPool, 2),
      preferredReligion: '',
      idVerified: false,
      idVerificationUrl: '',
      incomeVerified: false,
      professionalVerified: false,
      profileApprovalStatus: 'approved',
      inviteCode: '',
      profileVisibility: 'Public',
      showProfileToEveryone: true,
      showPhotosToEveryone: true,
      onboardingStep: 8,
      isDeleted: false,
      status: 'active',
      deletedAt: null,
      scheduledHardDeleteAt: null,
      termsAccepted: true,
      termsAcceptedAt: FieldValue.serverTimestamp(),
      isTestUser: true, // ← flag for easy identification
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    },
  };
}

// ─── Main ────────────────────────────────────────────────────────────────────

async function run() {
  console.log('🦢 Creating 50 test users (25 male + 25 female)...\n');

  // Firestore batch limit is 500 — we only need 50, one batch is fine
  const batch = db.batch();
  let count = 0;

  for (let i = 0; i < 25; i++) {
    const male = buildUser(i, 'Male');
    batch.set(db.collection('users').doc(male.docId), male.data);
    console.log(`  ✅ ${male.docId}  →  ${male.data.name}, ${male.data.age}, ${male.data.city}`);
    count++;

    const female = buildUser(i, 'Female');
    batch.set(db.collection('users').doc(female.docId), female.data);
    console.log(`  ✅ ${female.docId}  →  ${female.data.name}, ${female.data.age}, ${female.data.city}`);
    count++;
  }

  console.log(`\n⏳ Committing batch (${count} users)...`);
  await batch.commit();
  console.log(`\n🎉 Done! ${count} test users created.`);
  console.log('\nTo delete them later, run:');
  console.log('  cd functions && node ../scripts/delete_test_users.js\n');
  process.exit(0);
}

run().catch(err => {
  console.error('❌ Error:', err);
  process.exit(1);
});
