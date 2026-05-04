const request = require('supertest');
const app = require('../app'); // Directly import app
const dbHandler = require('./setup');
const User = require('../models/User');

beforeAll(async () => {
  await dbHandler.connect();
  dbHandler.mockIo(app); // Inject mock IO
});
afterEach(async () => await dbHandler.clearDatabase());
afterAll(async () => await dbHandler.closeDatabase());

describe('Auth System', () => {
  const mockUser = {
    fullName: 'Test User',
    email: 'test@example.com',
    password: 'password123',
    phoneNumber: '03001234567',
    role: 'rider'
  };

  it('should register a new user successfully', async () => {
    const res = await request(app)
      .post('/api/auth/register')
      .send(mockUser);

    expect(res.statusCode).toEqual(201);
    expect(res.body.success).toBe(true);
    expect(res.body.email).toBe(mockUser.email);
    
    const user = await User.findOne({ email: mockUser.email });
    expect(user).toBeTruthy();
  });

  it('should not register a user with an existing email', async () => {
    await User.create(mockUser);
    
    const res = await request(app)
      .post('/api/auth/register')
      .send(mockUser);

    expect(res.statusCode).toEqual(409);
    expect(res.body.success).toBe(false);
  });

  it('should login successfully with correct credentials', async () => {
    // Manually create verified user
    const user = new User({ ...mockUser, isEmailVerified: true });
    await user.save();

    const res = await request(app)
      .post('/api/auth/login')
      .send({
        email: mockUser.email,
        password: mockUser.password
      });

    expect(res.statusCode).toEqual(200);
    expect(res.body.success).toBe(true);
    expect(res.body.token).toBeDefined();
  });

  it('should fail login with wrong password', async () => {
    const user = new User({ ...mockUser, isEmailVerified: true });
    await user.save();

    const res = await request(app)
      .post('/api/auth/login')
      .send({
        email: mockUser.email,
        password: 'wrongpassword'
      });

    expect(res.statusCode).toEqual(401);
    expect(res.body.success).toBe(false);
  });
});
