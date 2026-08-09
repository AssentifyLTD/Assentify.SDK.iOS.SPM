//
//  TenantThemeModel.swift
//  Pods
//
//  Created by TariQ on 11/02/2026.
//
import Foundation

public struct TenantThemeModel: Codable {
    
    public let id: Int
    public let tenantId: Int
    public let primaryColor: String
    public let accentColor: String
    public let backgroundCardColor: String
    public let topAndButtonColor: String
    public let backgroundBodyColor: String
    public let textColor: String
    public let secondaryTextColor: String
    public let logo: String?
    public let logoIcon: String?
    public let logoAccent: String?
    public let adminPrimaryLogo: String?
    public let stepperType: Int
    public let headerText: String?
    public let icon: String?
    public let loaderType: Int
    public let name: String?
    public let isDefault: Bool
    
}

