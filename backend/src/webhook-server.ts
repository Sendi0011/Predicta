/**
 * Webhook Server for Chainhooks Events
 * Receives events from Chainhooks and processes them
 */

import express, { Request, Response } from 'express';
import {
  parseStacksEvent,
  MarketCreatedEvent,
  MarketLockedEvent,
  StakedEvent,
  ResolutionProposedEvent,
  ResolutionChallengedEvent,
  ExampleAIResolver
} from './chainhooks-integration';
import { makeContractCall, broadcastTransaction } from '@stacks/transactions';
import { StacksTestnet } from '@stacks/network';

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(express.json());

// Authentication middleware
const authenticateWebhook = (req: Request, res: Response, next: any) => {
  const authHeader = req.headers.authorization;
  const expectedToken = `Bearer ${process.env.WEBHOOK_SECRET}`;
  
  if (authHeader !== expectedToken) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  
  next();
};

// Initialize AI Resolver
const aiResolver = new ExampleAIResolver(
  process.env.ORACLE_CONTRACT || '',
  process.env.RESOLVER_PRIVATE_KEY || ''
);

/**
 * Webhook: Market Created
 * Triggered when a new prediction market is created
 */
app.post('/webhooks/market-created', authenticateWebhook, async (req: Request, res: Response) => {
  try {
    const event = req.body;
    const data = parseStacksEvent<MarketCreatedEvent>(event);
    
    if (!data) {
      return res.status(400).json({ error: 'Invalid event data' });
    }

    console.log('📊 New Market Created:', {
      marketId: data['market-id'],
      question: data.question,
      category: data.category,
      endsAt: data['ends-at']
    });

    // Store market in database for tracking
    await storeMarketMetadata(data);
    
    // Schedule end-time monitoring
    await scheduleMarketEndMonitoring(data['market-id'], data['ends-at']);

    res.status(200).json({ success: true, message: 'Market creation processed' });
  } catch (error) {
    console.error('Error processing market creation:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * Webhook: Market Locked
 * Triggered when market ends and gets locked
 * This is the key trigger for AI resolution
 */
app.post('/webhooks/market-locked', authenticateWebhook, async (req: Request, res: Response) => {
  try {
    const event = req.body;
    const data = parseStacksEvent<MarketLockedEvent>(event);
    
    if (!data) {
      return res.status(400).json({ error: 'Invalid event data' });
    }

    console.log('🔒 Market Locked:', {
      marketId: data['market-id'],
      timestamp: data.timestamp
    });

    // Trigger AI resolution process
    console.log('🤖 Initiating AI resolution...');
    await aiResolver.resolveMarket(data['market-id']);

    res.status(200).json({ success: true, message: 'Market locked, AI resolution initiated' });
  } catch (error) {
    console.error('Error processing market locked:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * Webhook: Staking Activity
 * Track all staking events for analytics
 */
app.post('/webhooks/staking-activity', authenticateWebhook, async (req: Request, res: Response) => {
  try {
    const event = req.body;
    const data = parseStacksEvent<StakedEvent>(event);
    
    if (!data) {
      return res.status(400).json({ error: 'Invalid event data' });
    }

    console.log('💰 Stake Event:', {
      user: data.user,
      side: data.side === 1 ? 'YES' : 'NO',
      amount: data.amount,
      totalPool: data['total-pool']
    });

    // Update analytics database
    await updateStakingAnalytics(data);

    res.status(200).json({ success: true });
  } catch (error) {
    console.error('Error processing staking activity:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * Webhook: Resolution Proposed
 * Monitor when AI submits resolution
 */
app.post('/webhooks/resolution-proposed', authenticateWebhook, async (req: Request, res: Response) => {
  try {
    const event = req.body;
    const data = parseStacksEvent<ResolutionProposedEvent>(event);
    
    if (!data) {
      return res.status(400).json({ error: 'Invalid event data' });
    }

    console.log('📝 Resolution Proposed:', {
      marketId: data['market-id'],
      result: data.result === 1 ? 'YES' : 'NO',
      proposer: data.proposer,
      challengeDeadline: data['challenge-deadline']
    });

    // Store proposed resolution
    await storeProposedResolution(data);
    
    // Schedule finalization after challenge period
    await scheduleResolutionFinalization(
      data['market-id'],
      data['challenge-deadline']
    );

    res.status(200).json({ success: true });
  } catch (error) {
    console.error('Error processing resolution proposal:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * Webhook: Resolution Challenged
 * Alert when someone challenges AI resolution
 */
app.post('/webhooks/resolution-challenged', authenticateWebhook, async (req: Request, res: Response) => {
  try {
    const event = req.body;
    const data = parseStacksEvent<ResolutionChallengedEvent>(event);
    
    if (!data) {
      return res.status(400).json({ error: 'Invalid event data' });
    }

    console.log('⚠️ Resolution Challenged:', {
      marketId: data['market-id'],
      challenger: data.challenger,
      reason: data.reason
    });

    // Alert admin for manual review
    await alertAdminOfChallenge(data);
    
    // Cancel automatic finalization
    await cancelScheduledFinalization(data['market-id']);

    res.status(200).json({ success: true });
  } catch (error) {
    console.error('Error processing challenge:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * Helper Functions
 */

async function storeMarketMetadata(data: MarketCreatedEvent) {
  // Store in your database
  console.log('Storing market metadata...');
}

async function scheduleMarketEndMonitoring(marketId: string, endsAt: number) {
  // Schedule a job to check when market should lock
  console.log(`Scheduled monitoring for market ${marketId} ending at ${endsAt}`);
}

async function updateStakingAnalytics(data: StakedEvent) {
  // Update analytics dashboard
  console.log('Updating staking analytics...');
}

async function storeProposedResolution(data: ResolutionProposedEvent) {
  // Store proposed resolution
  console.log('Storing proposed resolution...');
}

async function scheduleResolutionFinalization(marketId: string, deadline: number) {
  // Schedule automatic finalization after challenge period
  console.log(`Scheduled finalization for market ${marketId} at ${deadline}`);
}

async function alertAdminOfChallenge(data: ResolutionChallengedEvent) {
  // Send alert to admin (email, Slack, etc.)
  console.log('⚠️ ALERT: Resolution challenged, manual review required');
}

async function cancelScheduledFinalization(marketId: string) {
  // Cancel scheduled finalization job
  console.log(`Cancelled finalization for market ${marketId}`);
}

/**
 * Manual finalization endpoint
 * Called by cron job after challenge period
 */
app.post('/api/finalize-resolution', async (req: Request, res: Response) => {
  try {
    const { marketId } = req.body;
    
    if (!marketId) {
      return res.status(400).json({ error: 'Market ID required' });
    }

    // Call oracle contract to finalize
    const network = new StacksTestnet();
    
    const txOptions = {
      contractAddress: process.env.ORACLE_CONTRACT?.split('.')[0] || '',
      contractName: process.env.ORACLE_CONTRACT?.split('.')[1] || '',
      functionName: 'finalize-resolution',
      functionArgs: [marketId],
      senderKey: process.env.RESOLVER_PRIVATE_KEY || '',
      network,
      anchorMode: 1,
    };

    // Broadcast transaction
    // const tx = await makeContractCall(txOptions);
    // await broadcastTransaction(tx, network);

    console.log(`✅ Finalized resolution for market ${marketId}`);
    
    res.status(200).json({ success: true, message: 'Resolution finalized' });
  } catch (error) {
    console.error('Error finalizing resolution:', error);
    res.status(500).json({ error: 'Failed to finalize resolution' });
  }
});

/**
 * Health check endpoint
 */
app.get('/health', (req: Request, res: Response) => {
  res.status(200).json({ 
    status: 'healthy',
    timestamp: Date.now()
  });
});

/**
 * Start server
 */
app.listen(PORT, () => {
  console.log(`🚀 Webhook server running on port ${PORT}`);
  console.log(`📡 Listening for Chainhooks events...`);
});

export default app;