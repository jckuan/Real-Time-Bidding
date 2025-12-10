// Configuration
// Switch between local and AWS deployment
const USE_AWS = true;

window.API_BASE_URL = USE_AWS 
  ? 'http://rtb-alb-1080675720.us-west-2.elb.amazonaws.com/api/v1'
  : 'http://localhost:3000/api/v1';

window.WS_URL = USE_AWS
  ? 'http://rtb-alb-1080675720.us-west-2.elb.amazonaws.com'
  : 'http://localhost:3000';
