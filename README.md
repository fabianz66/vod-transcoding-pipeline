🎬 Zero-Cost VOD Orchestrator Architecture

Objective: Build a complete, asynchronous Video-on-Demand (VOD) pipeline that ingests raw video, generates an ABR (Adaptive Bitrate) ladder, and packages it for DASH/HLS—all while completely avoiding cloud egress fees.

🛠️ The Tech Stack

Frontend: Next.js (React), dash.js or hls.js for playback on the web. ExoPlayer for Android. AVPlayer for iOS.

Backend API: Ruby on Rails (API-only mode) + PostgreSQL.

Background Processing: Redis + Sidekiq (running locally).

Transcoding Engine: Custom FFmpeg single-pass bash scripts / C++ bindings.

Cloud Storage: Cloudflare R2 (S3-compatible, $0 egress bandwidth).

🔄 The Architecture Flow

Direct-to-Cloud Upload: The Next.js frontend requests a pre-signed URL from the Rails API. The client uploads the raw .mp4 (Mezzanine file) directly to a private Cloudflare R2 bucket.

Job Orchestration: Once the upload succeeds, Next.js notifies Rails. Rails creates a database record and pushes a transcoding job to the Sidekiq queue.

Local Worker Processing: A local Sidekiq worker picks up the job, downloads the Mezzanine file from R2, and executes the multi-bitrate FFmpeg command (generating 1080p, 720p, and 360p CMAF chunks + .mpd/.m3u8 manifests).

Delivery Push: The worker uploads the generated .m4s chunks and manifests to a public-facing Cloudflare R2 delivery bucket, then cleans up the local storage.

Playback: The Next.js UI loads the video player, pointing directly to the Cloudflare R2 manifest URL.