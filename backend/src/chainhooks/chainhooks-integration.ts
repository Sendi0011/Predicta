/**
 * Chainhooks Integration for Prediction Market
 * Monitors on-chain events and triggers AI oracle resolution
 * Uses @hirosystems/chainhooks-client
 */

import {
    ChainhooksClient,
    StacksEvent,
  } from '@hirosystems/chainhooks-client';
  
  
  type StacksChainhookPredicate = {
    uuid: string;
    name: string;
    version: number;
    networks: Record<string, any>;
  };
  

  // Configuration
  interface ChainhookConfig {
    baseUrl: string;
    authToken?: string;
  }
  
  const CHAINHOOK_CONFIG: ChainhookConfig = {
    baseUrl: process.env.CHAINHOOK_BASE_URL || 'http://localhost:20456',
    authToken: process.env.CHAINHOOK_AUTH_TOKEN
  };
  
  // Contract addresses (update with your deployed contracts)
  const CONTRACTS = {
    market: process.env.MARKET_CONTRACT || 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.market',
    oracle: process.env.ORACLE_CONTRACT || 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.ai-oracle',
    factory: process.env.FACTORY_CONTRACT || 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.market-factory'
  };
  
  /**
   * Initialize Chainhook Client
   */
  export function createChainhookClient() {
    return new ChainhooksClient({
      baseUrl: CHAINHOOK_CONFIG.baseUrl,
      authToken: CHAINHOOK_CONFIG.authToken,
    });
  }
  
  
  /**
   * Predicate for Market Creation Events
   * Triggers when a new market is created
   */
  export const marketCreationPredicate: StacksPredicate = {
    uuid: 'prediction-market-creation',
    name: 'Market Creation Monitor',
    version: 1,
    networks: {
      testnet: {
        'if_this': {
          scope: 'print_event',
          contract_identifier: CONTRACTS.factory,
          contains: 'market-created'
        },
        'then_that': {
          http_post: {
            url: `${process.env.EXTERNAL_BASE_URL}/webhooks/market-created`,
            authorization_header: `Bearer ${process.env.WEBHOOK_SECRET}`
          }
        },
        start_block: 0
      }
    }
  };
  
  /**
   * Predicate for Market Locked Events
   * Triggers when market ends and gets locked
   */
  export const marketLockedPredicate: StacksPredicate = {
    uuid: 'prediction-market-locked',
    name: 'Market Locked Monitor',
    version: 1,
    networks: {
      testnet: {
        'if_this': {
          scope: 'print_event',
          contract_identifier: CONTRACTS.market,
          contains: 'market-locked'
        },
        'then_that': {
          http_post: {
            url: `${process.env.EXTERNAL_BASE_URL}/webhooks/market-locked`,
            authorization_header: `Bearer ${process.env.WEBHOOK_SECRET}`
          }
        },
        start_block: 0
      }
    }
  };
  
  /**
   * Predicate for Stake Events
   * Monitors all staking activity for analytics
   */
  export const stakingPredicate: StacksPredicate = {
    uuid: 'prediction-market-staking',
    name: 'Staking Activity Monitor',
    version: 1,
    networks: {
      testnet: {
        'if_this': {
          scope: 'print_event',
          contract_identifier: CONTRACTS.market,
          contains: 'staked'
        },
        'then_that': {
          http_post: {
            url: `${process.env.EXTERNAL_BASE_URL}/webhooks/staking-activity`,
            authorization_header: `Bearer ${process.env.WEBHOOK_SECRET}`
          }
        },
        start_block: 0
      }
    }
  };
  
  /**
   * Predicate for Resolution Proposals
   * Triggers when AI submits a resolution
   */
  export const resolutionProposedPredicate: StacksPredicate = {
    uuid: 'prediction-resolution-proposed',
    name: 'Resolution Proposed Monitor',
    version: 1,
    networks: {
      testnet: {
        'if_this': {
          scope: 'print_event',
          contract_identifier: CONTRACTS.oracle,
          contains: 'resolution-proposed'
        },
        'then_that': {
          http_post: {
            url: `${process.env.EXTERNAL_BASE_URL}/webhooks/resolution-proposed`,
            authorization_header: `Bearer ${process.env.WEBHOOK_SECRET}`
          }
        },
        start_block: 0
      }
    }
  };
  
  /**
   * Predicate for Resolution Challenges
   * Monitors challenge events during the challenge period
   */
  export const resolutionChallengedPredicate: StacksPredicate = {
    uuid: 'prediction-resolution-challenged',
    name: 'Resolution Challenge Monitor',
    version: 1,
    networks: {
      testnet: {
        'if_this': {
          scope: 'print_event',
          contract_identifier: CONTRACTS.oracle,
          contains: 'resolution-challenged'
        },
        'then_that': {
          http_post: {
            url: `${process.env.EXTERNAL_BASE_URL}/webhooks/resolution-challenged`,
            authorization_header: `Bearer ${process.env.WEBHOOK_SECRET}`
          }
        },
        start_block: 0
      }
    }
  };
  
  /**
   * Register all predicates with the Chainhook server
   */
  export async function registerAllPredicates(client: ChainhooksClient) {
    const predicates = [
      marketCreationPredicate,
      marketLockedPredicate,
      stakingPredicate,
      resolutionProposedPredicate,
      resolutionChallengedPredicate
    ];
  
    for (const predicate of predicates) {
      try {
        await client.createPredicate(predicate as any);
        console.log(`✓ Registered predicate: ${predicate.name}`);
      } catch (error) {
        console.error(`✗ Failed to register ${predicate.name}:`, error);
      }
    }
  }
  
  /**
   * Event Handler Types
   */
  export interface MarketCreatedEvent {
    'market-address': string;
    'market-id': string;
    creator: string;
    question: string;
    'ends-at': number;
    category: string;
  }
  
  export interface MarketLockedEvent {
    'market-id': string;
    timestamp: number;
  }
  
  export interface StakedEvent {
    user: string;
    side: number;
    amount: string;
    'total-pool': string;
  }
  
  export interface ResolutionProposedEvent {
    'market-id': string;
    result: number;
    proposer: string;
    'challenge-deadline': number;
  }
  
  export interface ResolutionChallengedEvent {
    'market-id': string;
    challenger: string;
    reason: string;
  }
  
  /**
   * Parse Stacks event data
   */
  export function parseStacksEvent<T>(event: StacksEvent): T | null {
    try {
      // Extract print event data from StacksEvent
      if (!event || !event.data) {
        return null;
      }
  
      // Parse the event data
      return event.data as T;
    } catch (error) {
      console.error('Failed to parse event:', error);
      return null;
    }
  }
  
  /**
   * Example: Handle Market Locked Event to Trigger AI Resolution
   */
  export async function handleMarketLocked(
    event: StacksEvent,
    aiResolverService: AIResolverService
  ) {
    const data = parseStacksEvent<MarketLockedEvent>(event);
    
    if (!data) {
      console.error('Failed to parse market locked event');
      return;
    }
  
    console.log(`Market ${data['market-id']} locked at block ${data.timestamp}`);
    
    // Trigger AI resolution process
    try {
      await aiResolverService.resolveMarket(data['market-id']);
      console.log(`✓ AI resolution initiated for market ${data['market-id']}`);
    } catch (error) {
      console.error(`✗ Failed to resolve market ${data['market-id']}:`, error);
    }
  }
  
  /**
   * Mock AI Resolver Service Interface
   * Replace with your actual AI resolution logic
   */
  interface AIResolverService {
    resolveMarket(marketId: string): Promise<void>;
  }
  
  /**
   * Example AI Resolver Implementation
   */
  export class ExampleAIResolver implements AIResolverService {
    private oracleContract: string;
    private privateKey: string;
  
    constructor(oracleContract: string, privateKey: string) {
      this.oracleContract = oracleContract;
      this.privateKey = privateKey;
    }
  
    async resolveMarket(marketId: string): Promise<void> {
      // 1. Fetch market metadata
      const marketData = await this.fetchMarketData(marketId);
      
      // 2. Use AI to analyze and determine outcome
      const aiResult = await this.analyzeWithAI(marketData);
      
      // 3. Submit resolution to oracle contract
      await this.submitResolution(marketId, aiResult);
    }
  
    private async fetchMarketData(marketId: string) {
      // Fetch market question and context from chain
      return {
        question: 'Will Bitcoin reach $100k in 2024?',
        category: 'Crypto',
        sources: []
      };
    }
  
    private async analyzeWithAI(marketData: any): Promise<number> {
      // Call your AI service (OpenAI, Claude, custom model, etc.)
      // Return 1 for YES, 2 for NO
      return 1; // Example
    }
  
    private async submitResolution(marketId: string, result: number) {
      // Submit transaction to oracle contract
      // This would use @stacks/transactions
      console.log(`Submitting resolution: ${marketId} = ${result}`);
    }
  }
  
  /**
   * Main initialization function
   */
  export async function initializeChainhooks() {
    const client = createChainhookClient();
    
    console.log('Initializing Chainhooks...');
    
    // Register all predicates
    await registerAllPredicates(client);
    
    console.log('✓ Chainhooks initialized successfully');
    
    return client;
  }
  
  // Export for use in your application
  export default {
    createChainhookClient,
    registerAllPredicates,
    parseStacksEvent,
    handleMarketLocked,
    ExampleAIResolver
  };