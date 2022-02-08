# import Config
# config :membrane_timescaledb_reporter, Membrane.Telemetry.TimescaleDB.Repo,
#   database: "membrane_timescaledb_reporter",
#   username: "postgres",
#   password: "postgres",
#   hostname: "localhost",
#   chunk_time_interval: "3 minutes",
#   chunk_compress_policy_interval: "1 minute",
#   log: false



# config :membrane_core,
#   telemetry_flags: [
#     :links,
#     :inits_and_terminates,
#     {:metrics, [:queue_len]}
#   ]
# config :membrane_timescaledb_reporter,
#   reporters: 5, # number of reporter's workers
#   auto_migrate?: true # decides if the auto migration task should get triggered during supervisor initialization
