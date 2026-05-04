const request = require('supertest');
const { app } = require('../server');
const dbHandler = require('./setup');
const User = require('../models/User');
const path = require('path');
const fs = require('fs');

beforeAll(async () => {
  await dbHandler.connect();
  // Ensure uploads/kyc exists for tests
  const dir = path.join(__dirname, '../uploads/kyc');
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
});

afterEach(async () => await dbHandler.clearDatabase());
afterAll(async () => await dbHandler.closeDatabase());

describe('KYC System', () => {
  const driverData = {
    fullName: 'Test Driver',
    email: 'driver@example.com',
    password: 'password123',
    phoneNumber: '03009876543',
    role: 'driver'
  };

  const getAuthToken = async () => {
    const user = new User({ ...driverData, isEmailVerified: true });
    await user.save();
    const res = await request(app).post('/api/auth/login').send({
      email: driverData.email,
      password: driverData.password
    });
    return res.body.token;
  };

  it('should upload KYC documents successfully', async () => {
    const token = await getAuthToken();
    const dummyFile = Buffer.from('dummy content');

    const res = await request(app)
      .post('/api/kyc/upload')
      .set('Authorization', `Bearer ${token}`)
      .attach('cnic_front', dummyFile, 'front.jpg')
      .attach('cnic_back', dummyFile, 'back.jpg')
      .attach('license', dummyFile, 'license.jpg')
      .attach('vehicle_reg', dummyFile, 'reg.jpg');

    expect(res.statusCode).toEqual(200);
    expect(res.body.success).toBe(true);
    expect(res.body.message).toContain('uploaded successfully');

    const user = await User.findOne({ email: driverData.email });
    expect(user.kyc.status).toBe('under_review');
    expect(user.kyc.cnicFrontImage).toBeDefined();
    expect(user.kyc.vehicleRegImage).toBeDefined();
  });

  it('should get KYC status', async () => {
    const token = await getAuthToken();
    const res = await request(app)
      .get('/api/kyc/status')
      .set('Authorization', `Bearer ${token}`);

    expect(res.statusCode).toEqual(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.status).toBeDefined();
  });
});
