#!/bin/bash

echo "🚀 CRDO Backend Deployment Script"
echo "=================================="

# Check if Supabase CLI is installed
if ! command -v supabase &> /dev/null; then
    echo "❌ Supabase CLI not found. Installing..."
    npm install -g supabase
fi

# Check if user is logged in
if ! supabase status &> /dev/null; then
    echo "🔐 Please login to Supabase..."
    supabase login
fi

echo ""
echo "📋 Deployment Steps:"
echo "1. Create a new Supabase project at https://supabase.com"
echo "2. Get your project reference (e.g., abc123def456)"
echo "3. Run this script with your project ref:"
echo "   ./DEPLOY_TO_PRODUCTION.sh YOUR_PROJECT_REF"
echo ""

if [ -z "$1" ]; then
    echo "❌ Please provide your Supabase project reference"
    echo "Usage: ./DEPLOY_TO_PRODUCTION.sh YOUR_PROJECT_REF"
    exit 1
fi

PROJECT_REF=$1
echo "🎯 Deploying to project: $PROJECT_REF"

# Link to project
echo "🔗 Linking to Supabase project..."
supabase link --project-ref $PROJECT_REF

# Deploy database migrations
echo "🗄️ Deploying database migrations..."
supabase db push

# Deploy functions
echo "⚡ Deploying Edge Functions..."
supabase functions deploy

echo ""
echo "✅ Deployment complete!"
echo ""
echo "📱 Next steps:"
echo "1. Update CRDO-Frontend/CRDO/BackendConfig.swift with your project URL:"
echo "   https://$PROJECT_REF.supabase.co/functions/v1"
echo "2. Change environment to .production"
echo "3. Test the app on your device"
echo "4. Archive and upload to TestFlight"
echo "" 