import tracer from 'dd-trace';

tracer.init({
  service: process.env.DD_SERVICE ?? 'nestjs-manual',
  env: process.env.DD_ENV ?? 'dev',
  version: process.env.DD_VERSION ?? 'local',
  logInjection: true,
  runtimeMetrics: true,
});

export default tracer;
