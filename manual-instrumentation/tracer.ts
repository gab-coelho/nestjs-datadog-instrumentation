import tracer from 'dd-trace';

tracer.init({
  service: process.env.DD_SERVICE,
  env: process.env.DD_ENV,
  version: process.env.DD_VERSION,
  logInjection: true,
  runtimeMetrics: true,
});

export default tracer;
