/**
 * Chainhooks Integration for Prediction Market
 * Monitors on-chain events and triggers AI oracle resolution
 * Uses @hirosystems/chainhooks-client
 */

import {
    ChainhooksClient,
    StacksEvent,
  } from '@hirosystems/chainhooks-client';
  
  /* -------------------------------------------------------------------------- */
  /*                                   Types                                    */
  /* -------------------------------------------------------------------------- */
  
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
  
  /* -------------------------------------------------------------------------- */
  /*                               Configuration                                */
  /* -------------------------------------------------------------------------- */
  
  const CHAINHOOK_CONFIG: ChainhookConfig = {
    baseUrl: process.env.CHAINHOOK_BASE_URL || 'http://localhost:20456',
    authToken: process.env.CHAINHOOK_AUTH_TOKEN,
  };
  
  // Contract addresses (update with your deployed contracts)
  const CONTRACTS = {
    market:
      process.env.MARKET_CONTRACT ||
      'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.market',
    oracle:
      process.env.ORACLE_CONTRACT ||
      'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.ai-oracle',
    factory:
      process.env.FACTORY_CONTRACT ||
      'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.market-factory',
  };
  
  /* -------------------------------------------------------------------------- */
  /*                           Chainhooks Client Init                            */
  /* -------------------------------------------------------------------------- */
  
  export function createChainhookClient() {
    return new ChainhooksClient({
      baseUrl: CHAINHOOK_CONFIG.baseUrl,
      authToken: CHAINHOOK_CONFIG.authToken,
    });
  }
  
  /* -------------------------------------------------------------------------- */
  /*                                Predicates                                  */
  /* -------------------------------------------------------------------------- */
  
  /**
   * Predicate for Market Creation Events
   * Triggers when a new market is created
   */
  export const marketCreationPredicate: StacksChainhookPredicate = {
    uuid: 'prediction-market-creation',
    name: 'Market Creation Monitor',
    version: 1,
    networks: {
      testnet: {
        if_this: {
          scope: 'print_event',
          contract_identifier: CONTRACTS.factory,
          contains: 'market-created',
        },
        then_that: {
          http_post: {
            url: `${process.env.EXTERNAL_BASE_URL}/webhooks/market-created`,
            authorization_header: `Bearer ${process.env.WEBHOOK_SECRET}`,
          },
        },
        start_block: 0,
      },
    },
  };
  
  export const marketLockedPredicate: StacksChainhookPredicate = {
    uuid: 'prediction-market-locked',
    name: 'Market Locked Monitor',
    version: 1,
    networks: {
      testnet: {
        if_this: {
          scope: 'print_event',
          contract_identifier: CONTRACTS.market,
          contains: 'market-locked',
        },
        then_that: {
          http_post: {
            url: `${process.env.EXTERNAL_BASE_URL}/webhooks/market-locked`,
            authorization_header: `Bearer ${process.env.WEBHOOK_SECRET}`,
          },
        },
        start_block: 0,
      },
    },
  };
  
  export const stakingPredicate: StacksChainhookPredicate = {
    uuid: 'prediction-market-staking',
    name: 'Staking Activity Monitor',
    version: 1,
    networks: {
      testnet: {
        if_this: {
          scope: 'print_event',
          contract_identifier: CONTRACTS.market,
          contains: 'staked',
        },
        then_that: {
          http_post: {
            url: `${process.env.EXTERNAL_BASE_URL}/webhooks/staking-activity`,
            authorization_header: `Bearer ${process.env.WEBHOOK_SECRET}`,
          },
        },
        start_block: 0,
      },
    },
  };
  
  export const resolutionProposedPredicate: StacksChainhookPredicate = {
    uuid: 'prediction-resolution-proposed',
    name: 'Resolution Proposed Monitor',
    version: 1,
    networks: {
      testnet: {
        if_this: {
          scope: 'print_event',
          contract_identifier: CONTRACTS.oracle,
          contains: 'resolution-proposed',
        },
        then_that: {
          http_post: {
            url: `${process.env.EXTERNAL_BASE_URL}/webhooks/resolution-proposed`,
            authorization_header: `Bearer ${process.env.WEBHOOK_SECRET}`,
          },
        },
        start_block: 0,
      },
    },
  };
  
  /**
   * Predicate for Resolution Challenges
   * Monitors challenge events during the challenge period
   */
  export const resolutionChallengedPredicate: StacksChainhookPredicate = {
    uuid: 'prediction-resolution-challenged',
    name: 'Resolution Challenge Monitor',
    version: 1,
    networks: {
      testnet: {
        if_this: {
          scope: 'print_event',
          contract_identifier: CONTRACTS.oracle,
          contains: 'resolution-challenged',
        },
        then_that: {
          http_post: {
            url: `${process.env.EXTERNAL_BASE_URL}/webhooks/resolution-challenged`,
            authorization_header: `Bearer ${process.env.WEBHOOK_SECRET}`,
          },
        },
        start_block: 0,
      },
    },
  };
  
  /* -------------------------------------------------------------------------- */
  /*                         Predicate Registration                              */
  /* -------------------------------------------------------------------------- */
  
  export async function registerAllPredicates(client: ChainhooksClient) {
    const predicates = [
      marketCreationPredicate,
      marketLockedPredicate,
      stakingPredicate,
      resolutionProposedPredicate,
      resolutionChallengedPredicate,
    ];
  
    for (const predicate of predicates) {
      try {
        await client.registerPredicate(predicate);
        console.log(`✓ Registered predicate: ${predicate.name}`);
      } catch (error) {
        console.error(`✗ Failed to register ${predicate.name}:`, error);
      }
    }
  }
  
  /* -------------------------------------------------------------------------- */
  /*                              Event Types                                   */
  /* -------------------------------------------------------------------------- */
  
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
  
  /* -------------------------------------------------------------------------- */
  /*                          Event Parsing Helper                               */
  /* -------------------------------------------------------------------------- */
  
  export function parseStacksEvent<T>(event: StacksEvent): T | null {
    if (event.type !== 'print_event') return null;
  
    const value = (event as any).value;
    if (!value) return null;
  
    return value as T;
  }
  
  /* -------------------------------------------------------------------------- */
  /*                      Example Market Locked Handler                          */
  /* -------------------------------------------------------------------------- */
  
  export async function handleMarketLocked(
    event: StacksEvent,
    aiResolverService: AIResolverService
  ) {
    const data = parseStacksEvent<MarketLockedEvent>(event);
  
    if (!data) {
      console.error('Failed to parse market locked event');
      return;
    }
  
    console.log(`Market ${data['market-id']} locked at ${data.timestamp}`);
  
    try {
      await aiResolverService.resolveMarket(data['market-id']);
      console.log(`✓ AI resolution initiated`);
    } catch (error) {
      console.error(`✗ Resolution failed`, error);
    }
  }
  
  /* -------------------------------------------------------------------------- */
  /*                         AI Resolver Interface                               */
  /* -------------------------------------------------------------------------- */
  
  interface AIResolverService {
    resolveMarket(marketId: string): Promise<void>;
  }
  
  /* -------------------------------------------------------------------------- */
  /*                      Example AI Resolver Implementation                     */
  /* -------------------------------------------------------------------------- */
  
  export class ExampleAIResolver implements AIResolverService {
    constructor(
      private oracleContract: string,
      private privateKey: string
    ) {}
  
    async resolveMarket(marketId: string): Promise<void> {
      // 1. Fetch market metadata
      const marketData = await this.fetchMarketData(marketId);
      const result = await this.analyzeWithAI(marketData);
      await this.submitResolution(marketId, result);
    }
  
    private async fetchMarketData(marketId: string) {
      // Fetch market question and context from chain
      return {
        question: 'Will Bitcoin reach $100k in 2024?',
        category: 'Crypto',
        sources: [],
      };
    }
  
    private async analyzeWithAI(_marketData: any): Promise<number> {
      return 1; // YES
    }
  
    private async submitResolution(marketId: string, result: number) {
      console.log(`Submitting resolution: ${marketId} => ${result}`);
    }
  }
  
  /* -------------------------------------------------------------------------- */
  /*                              Initialization                                */
  /* -------------------------------------------------------------------------- */
  
  export async function initializeChainhooks() {
    const client = createChainhookClient();
  
    console.log('Initializing Chainhooks...');
    
    // Register all predicates
    await registerAllPredicates(client);
    console.log('✓ Chainhooks initialized');
  
    return client;
  }
  
  /* -------------------------------------------------------------------------- */
  /*                                   Export                                   */
  /* -------------------------------------------------------------------------- */
  
  export default {
    createChainhookClient,
    registerAllPredicates,
    parseStacksEvent,
    handleMarketLocked,
    ExampleAIResolver,
  };
  