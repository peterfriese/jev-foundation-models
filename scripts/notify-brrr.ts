import { Command } from 'commander';

interface NotifyOptions {
  title?: string;
  subtitle?: string;
  message?: string;
  threadId?: string;
  sound?: string;
  interruptionLevel?: string;
}

const program = new Command();
program
  .option('-t, --title <title>', 'Notification Title', 'ACMD Agent Alert')
  .option('--subtitle <subtitle>', 'Notification Subtitle')
  .option('-m, --message <message>', 'Notification Message', 'Task completed.')
  .option('--thread-id <threadId>', 'Notification Thread ID', 'acmd-general')
  .option('--sound <sound>', 'Sound effect', 'bubbly_success_ding')
  .option('--interruption-level <level>', 'Interruption tier', 'active')
  .parse(process.argv);

const opts = program.opts<NotifyOptions>();
const token = process.env.BRRRR_TOKEN;

async function sendNotification() {
  if (!token) {
    // Fallback to local terminal bell and macOS native notification
    process.stdout.write('\x07');
    console.log(`\n🔔 [Local Alert] ${opts.title}: ${opts.message}`);
    return;
  }

  try {
    const payload = {
      title: opts.title,
      subtitle: opts.subtitle,
      body: opts.message,
      threadId: opts.threadId,
      sound: opts.sound,
      interruptionLevel: opts.interruptionLevel
    };

    const res = await fetch(`https://api.brrr.now/v1/notify`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`
      },
      body: JSON.stringify(payload)
    });

    if (!res.ok) {
      console.warn(`[brrrr] Push notification failed: ${res.statusText}`);
    } else {
      console.log(`[brrrr] Push notification sent successfully!`);
    }
  } catch (err: any) {
    console.warn(`[brrrr] Offline or error: ${err.message}`);
  }
}

sendNotification();
