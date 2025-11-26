//
//  UpdateProfileRequest.swift
//  YAL
//
//  Created by Vishal Bhadade on 11/04/25.
//

import Foundation

struct UpdateProfileRequest: Request {
    var about: String?
    var mobile: String?
    var name: String?
    var email: String?
    var gender: String?
    var dob: String?
    var profession: String?
    var mxcProfile: String?
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        
        if let about = about { dict["about"] = about }
        if let mobile = mobile { dict["mobile"] = mobile }
        if let name = name { dict["name"] = name }
        if let email = email { dict["email"] = email }
        if let gender = gender { dict["gender"] = gender }
        if let dob = dob { dict["dob"] = dob }
        if let profession = profession { dict["profession"] = profession }
        if let mxcProfile = mxcProfile { dict["mxcProfile"] = mxcProfile }
        
        return dict
    }
}

